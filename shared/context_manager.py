"""
shared/context_manager.py — Shared Context Layer for Profit-First SaaS Inc.

Provides a cross-agent read/write interface for the global_state.json file so
agents can share context without relying solely on file-path conventions.

Also handles project archiving: moves all artefacts for a completed project
into archives/<project_name>/ and records the outcome in project_history.

Usage:
    python3 shared/context_manager.py read <key>
    python3 shared/context_manager.py write <key> <json_value>
    python3 shared/context_manager.py pipeline <stage>
    python3 shared/context_manager.py set_project <project_name>
    python3 shared/context_manager.py archive <project_name> <outcome>

Outcomes for archive: "greenlighted" | "vetoed" | "completed" | "failed"
"""

import json
import os
import sys
import shutil
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATE_PATH = os.path.join(BASE_DIR, "global_state.json")
ARCHIVES_DIR = os.path.join(BASE_DIR, "..", "archives")

PIPELINE_STAGES = [
    "idle",
    "scouting",
    "market_analysis",
    "tech_spec",
    "ceo_review",
    "audit",
    "done",
]

ARTEFACT_FILES = [
    "PAIN_POINTS.md",
    "MARKET_PLAN.md",
    "TECH_SPEC.md",
    "CEO_DECISION.md",
    "POST_MORTEM.md",
]


# ── State helpers ──────────────────────────────────────────────────────────────

def load_state() -> dict:
    if not os.path.exists(STATE_PATH):
        return {
            "version": 1,
            "last_updated": _today(),
            "active_project": None,
            "pipeline_stage": "idle",
            "daily_leads": [],
            "market_plan": {},
            "tech_spec": {},
            "ceo_decision": None,
            "revenue_events": [],
            "project_history": [],
        }
    with open(STATE_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def save_state(state: dict) -> None:
    state["last_updated"] = _today()
    with open(STATE_PATH, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2, ensure_ascii=False)


def _today() -> str:
    return datetime.now().strftime("%Y-%m-%d")


# ── Commands ───────────────────────────────────────────────────────────────────

def cmd_read(key: str) -> None:
    """Print the value of a top-level key from global_state.json."""
    state = load_state()
    if key not in state:
        print(f"Key '{key}' not found in global state.")
        sys.exit(1)
    print(json.dumps(state[key], indent=2, ensure_ascii=False))


def cmd_write(key: str, json_value: str) -> None:
    """Set a top-level key in global_state.json to a JSON-encoded value."""
    state = load_state()
    try:
        value = json.loads(json_value)
    except json.JSONDecodeError:
        # Accept bare strings without quotes for convenience.
        value = json_value
    state[key] = value
    save_state(state)
    print(f"✅  Set '{key}' in global state.")


def cmd_pipeline(stage: str) -> None:
    """Advance (or set) the pipeline stage."""
    if stage not in PIPELINE_STAGES:
        print(
            f"Unknown stage '{stage}'. Valid stages: {', '.join(PIPELINE_STAGES)}"
        )
        sys.exit(1)
    state = load_state()
    old_stage = state.get("pipeline_stage", "idle")
    state["pipeline_stage"] = stage
    save_state(state)
    print(f"Pipeline: {old_stage} → {stage}")


def cmd_set_project(project_name: str) -> None:
    """Mark a project as the active one and reset pipeline to scouting."""
    state = load_state()
    state["active_project"] = project_name
    state["pipeline_stage"] = "scouting"
    state["market_plan"] = {}
    state["tech_spec"] = {}
    state["ceo_decision"] = None
    save_state(state)
    print(f"🚀  Active project set to '{project_name}' — pipeline reset to scouting.")


def cmd_archive(project_name: str, outcome: str = "completed") -> None:
    """
    Archive all artefacts for project_name into archives/<project_name>/.

    Copies shared/*.md artefacts and all workspace HEARTBEAT/IDENTITY files into
    a timestamped archive folder, then records the project in project_history.
    """
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    archive_dir = os.path.join(ARCHIVES_DIR, f"{project_name}_{timestamp}")
    os.makedirs(archive_dir, exist_ok=True)

    copied = []
    for filename in ARTEFACT_FILES:
        src = os.path.join(BASE_DIR, filename)
        if os.path.exists(src):
            dst = os.path.join(archive_dir, filename)
            shutil.copy2(src, dst)
            copied.append(filename)

    # Save a snapshot of global_state at archive time.
    state = load_state()
    snapshot_path = os.path.join(archive_dir, "global_state_snapshot.json")
    with open(snapshot_path, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2, ensure_ascii=False)
    copied.append("global_state_snapshot.json")

    # Record in project history.
    history_entry = {
        "project_name": project_name,
        "outcome": outcome,
        "archived_at": datetime.now().isoformat(),
        "archive_path": archive_dir,
        "artefacts": copied,
        "treasury_at_archive": _get_treasury(),
    }
    state["project_history"].append(history_entry)
    state["active_project"] = None
    state["pipeline_stage"] = "idle"
    save_state(state)

    print(f"📦  Archived '{project_name}' ({outcome}) → {archive_dir}")
    print(f"    Files: {', '.join(copied)}")


def _get_treasury() -> int:
    """Read current treasury from LEDGER.json (best-effort)."""
    ledger_path = os.path.join(BASE_DIR, "LEDGER.json")
    try:
        with open(ledger_path, "r", encoding="utf-8") as f:
            return json.load(f).get("treasury", 0)
    except Exception:
        return 0


def cmd_history() -> None:
    """Print all past projects from project_history."""
    state = load_state()
    history = state.get("project_history", [])
    if not history:
        print("No archived projects yet.")
        return
    for entry in history:
        print(
            f"[{entry['archived_at'][:10]}] {entry['project_name']:30s} "
            f"{entry['outcome']:12s}  treasury={entry['treasury_at_archive']}"
        )


# ── Entrypoint ─────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print(
            "Usage:\n"
            "  python3 context_manager.py read <key>\n"
            "  python3 context_manager.py write <key> <json_value>\n"
            "  python3 context_manager.py pipeline <stage>\n"
            "  python3 context_manager.py set_project <project_name>\n"
            "  python3 context_manager.py archive <project_name> [outcome]\n"
            "  python3 context_manager.py history\n"
        )
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "read":
        if len(sys.argv) < 3:
            print("Usage: context_manager.py read <key>")
            sys.exit(1)
        cmd_read(sys.argv[2])

    elif cmd == "write":
        if len(sys.argv) < 4:
            print("Usage: context_manager.py write <key> <json_value>")
            sys.exit(1)
        cmd_write(sys.argv[2], sys.argv[3])

    elif cmd == "pipeline":
        if len(sys.argv) < 3:
            print("Usage: context_manager.py pipeline <stage>")
            sys.exit(1)
        cmd_pipeline(sys.argv[2])

    elif cmd == "set_project":
        if len(sys.argv) < 3:
            print("Usage: context_manager.py set_project <project_name>")
            sys.exit(1)
        cmd_set_project(sys.argv[2])

    elif cmd == "archive":
        if len(sys.argv) < 3:
            print("Usage: context_manager.py archive <project_name> [outcome]")
            sys.exit(1)
        outcome = sys.argv[3] if len(sys.argv) > 3 else "completed"
        cmd_archive(sys.argv[2], outcome)

    elif cmd == "history":
        cmd_history()

    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)


if __name__ == "__main__":
    main()
