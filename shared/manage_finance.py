import csv
import json
import sys
import os
from contextlib import contextmanager
from datetime import datetime

# Relative path resolution for cross-platform deployment
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LEDGER_PATH = os.path.join(BASE_DIR, "LEDGER.json")
AUDIT_LOG_PATH = os.path.join(BASE_DIR, "AUDIT_LOG.csv")
CULTURE_PATH = os.path.join(BASE_DIR, "CORP_CULTURE.md")
LOCK_PATH = LEDGER_PATH + ".lock"

# ---------------------------------------------------------------------------
# File locking — prevents race conditions when multiple agents run concurrently
# (e.g. CEO and Accountant both trigger manage_finance.py in the same window).
# On Unix/macOS/Linux: uses fcntl.flock (exclusive advisory lock).
# On Windows: uses a simple lock-file with O_EXCL (best-effort, not perfect).
# ---------------------------------------------------------------------------

try:
    import fcntl

    @contextmanager
    def _ledger_lock():
        """Exclusive lock for the entire read→modify→write lifecycle."""
        lock_fd = open(LOCK_PATH, "w")
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX)
            yield
        finally:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            lock_fd.close()

except ImportError:
    # Windows fallback: O_EXCL-based spin lock (adequate for low-concurrency use)
    import time

    @contextmanager
    def _ledger_lock():
        """Best-effort exclusive lock for Windows environments."""
        acquired = False
        for _ in range(30):          # try for up to ~3 s
            try:
                fd = os.open(LOCK_PATH, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                os.close(fd)
                acquired = True
                break
            except FileExistsError:
                time.sleep(0.1)
        if not acquired:
            print("Warning: Could not acquire ledger lock — proceeding without lock (Windows).")
        try:
            yield
        finally:
            if acquired:
                try:
                    os.remove(LOCK_PATH)
                except OSError:
                    pass


def log_event(event_type, agent_id, amount, reasoning):
    """Logs financial events to a persistent CSV for long-term analysis."""
    try:
        file_exists = os.path.exists(AUDIT_LOG_PATH)
        with open(AUDIT_LOG_PATH, "a", newline="") as f:
            writer = csv.writer(f, quoting=csv.QUOTE_ALL)
            if not file_exists or os.stat(AUDIT_LOG_PATH).st_size == 0:
                writer.writerow(["timestamp", "event_type", "agent_id", "amount", "reasoning"])
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            writer.writerow([timestamp, event_type, agent_id, amount, reasoning])
    except Exception as e:
        print(f"Warning: Could not write to audit log: {e}")


def _default_ledger(company_name="Profit-First SaaS Inc."):
    return {
        "company_name": company_name,
        "treasury": 500,
        "maturity_level": "Bootstrapping",
        "status": "growth",
        "last_updated": datetime.now().strftime("%Y-%m-%d"),
        "agents": {
            "scout":      {"points": 100, "generation": 1},
            "cmo":        {"points": 100, "generation": 1},
            "arch":       {"points": 100, "generation": 1},
            "ceo":        {"points": 100, "generation": 1},
            "accountant": {"points": 100, "generation": 1},
            # NOTE: Add any new agents here AND register them in openclaw.json.
            # Do NOT add agents here without a corresponding workspace + AGENTS.md.
        }
    }


def load_ledger():
    """Load ledger from disk. Must be called inside a _ledger_lock() block."""
    if not os.path.exists(LEDGER_PATH):
        return _default_ledger()
    with open(LEDGER_PATH, 'r') as f:
        return json.load(f)


def save_ledger(data):
    """Persist ledger to disk. Must be called inside a _ledger_lock() block."""
    data["last_updated"] = datetime.now().strftime("%Y-%m-%d")

    # Maturity Level Logic
    old_level = data.get("maturity_level", "Bootstrapping")
    treasury = data["treasury"]
    if treasury < 1000:
        data["maturity_level"] = "Bootstrapping"
    elif treasury < 10000:
        data["maturity_level"] = "Scaling"
    else:
        data["maturity_level"] = "Unicorn"

    if old_level != data["maturity_level"]:
        print(f"!!! EVOLUTION: Company has evolved to {data['maturity_level']} !!!")
        try:
            with open(CULTURE_PATH, "a") as f:
                f.write(f"\n## MILESTONE: Evolved to {data['maturity_level']} on {data['last_updated']}\n")
        except Exception:
            pass

    # Bankruptcy Protection Trigger
    if data["treasury"] < 100:
        data["status"] = "survival"
    else:
        data["status"] = "growth"

    with open(LEDGER_PATH, 'w') as f:
        json.dump(data, f, indent=2)


def record_revenue(amount, source_agent, reasoning):
    """
    Injects points into the treasury from external revenue (e.g., a sale or monetization).

    Distribution (sums exactly to `amount` — no silent truncation):
      - 70% → Treasury  (rounded)
      - 20% → Source agent bonus  (rounded)
      - Remainder split evenly among all agents; any leftover penny → Treasury
    """
    with _ledger_lock():
        ledger = load_ledger()
        amount = int(amount)
        n_agents = len(ledger["agents"])

        treasury_share = round(amount * 0.7)
        agent_bonus    = round(amount * 0.2)
        pool           = amount - treasury_share - agent_bonus   # exact remainder
        team_bonus     = pool // n_agents
        leftover       = pool - team_bonus * n_agents            # fractional pts → treasury

        ledger["treasury"] += treasury_share + leftover

        if source_agent in ledger["agents"]:
            ledger["agents"][source_agent]["points"] += agent_bonus
        else:
            # Unknown source agent — add bonus to treasury instead of crashing
            print(f"Warning: source agent '{source_agent}' not in ledger — agent_bonus added to treasury.")
            ledger["treasury"] += agent_bonus

        for agent in ledger["agents"]:
            ledger["agents"][agent]["points"] += team_bonus

        total_distributed = treasury_share + leftover + agent_bonus + team_bonus * n_agents
        print(f"💰 REVENUE RECORDED: +{amount} pts from {reasoning}")
        print(f"   Treasury: +{treasury_share + leftover}, {source_agent} Bonus: +{agent_bonus}, "
              f"Team Kickback: +{team_bonus} each (distributed total: {total_distributed})")
        save_ledger(ledger)
        log_event("revenue", source_agent, amount, reasoning)


def grant_bounty(amount, target_agent, task_description):
    """
    Grant a one-time bounty for critical survival tasks.
    Funds are taken from the Treasury.
    """
    with _ledger_lock():
        ledger = load_ledger()
        amount = int(amount)

        if ledger["treasury"] < amount:
            print(f"❌ ERROR: Treasury ({ledger['treasury']}) insufficient for bounty ({amount})")
            return

        if target_agent not in ledger["agents"]:
            print(f"❌ ERROR: Agent '{target_agent}' not found in ledger. "
                  f"Available agents: {list(ledger['agents'].keys())}")
            return

        ledger["treasury"] -= amount
        ledger["agents"][target_agent]["points"] += amount
        print(f"🎯 BOUNTY AWARDED: {amount} pts to {target_agent} for '{task_description}'")
        save_ledger(ledger)
        log_event("bounty", target_agent, -amount, task_description)


def score_agent(target_id, score, reasoning):
    with _ledger_lock():
        ledger = load_ledger()
        if target_id not in ledger["agents"]:
            print(f"Error: Agent {target_id} not found.")
            return

        score = int(score)
        # Balanced reward: Score 5 is neutral, 6+ gains points, 4- loses points
        # (Score - 5) * 4 means a perfect 10 gives +20, covering 2 days of costs
        change = (score - 5) * 4
        if score <= 2:
            print(f"!!! QUALITY ALERT: Heavy penalty applied for low-quality output from {target_id} !!!")
            change -= 15
        elif score >= 9:
            print(f"!!! EXCELLENCE: Bonus points awarded to {target_id} !!!")
            change += 5

        ledger["agents"][target_id]["points"] += change
        print(f"Scored {target_id} with {score}. Total Change: {change}. Reason: {reasoning}")
        save_ledger(ledger)
        log_event("score", target_id, change, f"Score: {score}, Reason: {reasoning}")


def log_token_usage(agent_id, input_tokens, output_tokens):
    """
    Deduct points for token consumption.

    Design intent (intentional dual deduction):
      API token costs are a REAL company expense. The penalty is therefore applied
      to BOTH the responsible agent (accountability) AND the shared treasury
      (cash-flow impact), mirroring how actual API bills work.
      The penalty rate scales down as the company matures so that Unicorn-stage
      companies are not crippled by high token volume.
    """
    with _ledger_lock():
        ledger = load_ledger()
        if agent_id not in ledger["agents"]:
            print(f"Warning: Agent '{agent_id}' not found in ledger — token usage not logged.")
            return

        level = ledger.get("maturity_level", "Bootstrapping")
        total_tokens = int(input_tokens) + int(output_tokens)

        if level == "Bootstrapping":
            token_penalty = total_tokens // 2000
        elif level == "Scaling":
            token_penalty = total_tokens // 5000
        else:
            token_penalty = total_tokens // 20000

        if token_penalty > 0:
            ledger["agents"][agent_id]["points"] -= token_penalty
            ledger["treasury"] -= token_penalty
            print(f"Token penalty ({level}): -{token_penalty} pts from both {agent_id} and treasury")
            log_event("token_penalty", agent_id, -token_penalty, f"Tokens: {total_tokens} ({level})")

        save_ledger(ledger)


def reset_ledger(company_name="Profit-First SaaS Inc."):
    """Reset ledger to baseline state. Intended for idempotent setup/re-setup."""
    with _ledger_lock():
        ledger = _default_ledger(company_name=company_name)
        with open(LEDGER_PATH, 'w') as f:
            json.dump(ledger, f, indent=2)
        print("Ledger has been reset to baseline.")
        return


def daily_audit():
    with _ledger_lock():
        ledger = load_ledger()
        print(f"--- Daily Financial Audit [{ledger['status'].upper()} MODE] ---")
        print(f"Treasury: {ledger['treasury']}")
        print(f"Maturity: {ledger['maturity_level']}")

        for agent_id, data in ledger["agents"].items():
            cost = 10
            if ledger["status"] == "survival":
                cost = 5

            data["points"] -= cost
            ledger["treasury"] -= cost
            print(f"Agent {agent_id}: {data['points']} pts (Daily cost: -{cost})")
            log_event("daily_cost", agent_id, -cost, "Daily audit operational cost")

            if data["points"] <= 0:
                print(f"!!! ALERT: Agent {agent_id} is BANKRUPT !!!")
                # NOTE: To add a new agent, register it in openclaw.json AND
                # create its workspace directory with AGENTS.md, SOUL.md, etc.
                # Do NOT add orphan entries here that lack a workspace.

        save_ledger(ledger)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python manage_finance.py [score|audit|tokens|revenue|bounty|reset] ...")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "score":
        score_agent(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "audit":
        daily_audit()
    elif cmd == "tokens":
        log_token_usage(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "revenue":
        record_revenue(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "bounty":
        grant_bounty(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "reset":
        company_name = sys.argv[2] if len(sys.argv) >= 3 else "Profit-First SaaS Inc."
        reset_ledger(company_name)
    else:
        print(f"Unknown command: {cmd}")
        print("Usage: python manage_finance.py [score|audit|tokens|revenue|bounty|reset] ...")
        sys.exit(1)
