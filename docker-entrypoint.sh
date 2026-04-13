#!/usr/bin/env bash
# =============================================================================
# Docker container entrypoint for Profit-Corp / OpenCLAW
# =============================================================================
# Runs at container start. Performs one-time setup if needed, then starts
# the OpenCLAW gateway.
# =============================================================================

set -euo pipefail

CORP_ROOT="${PROFIT_CORP_ROOT:-/home/openclaw/profit-corp}"
STATE_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
OPENCLAW_CONFIG="$STATE_DIR/openclaw.json"
OPENCLAW_TZ="${CORP_TIMEZONE:-UTC}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

echo "[entrypoint] Starting Profit-Corp gateway..."
echo "[entrypoint] Corp root: $CORP_ROOT"
echo "[entrypoint] State dir: $STATE_DIR"

ensure_workspace_shared_link() {
    local workspace="$1"
    local shared_target="$CORP_ROOT/shared"
    local shared_link="$workspace/shared"
    local backup="${shared_link}.bak.$(date +%Y%m%d_%H%M%S)"

    if [[ ! -d "$workspace" ]]; then
        echo "[entrypoint] WARN: workspace missing, cannot wire shared link: $workspace"
        return 0
    fi

    if [[ -L "$shared_link" ]]; then
        return 0
    fi

    if [[ -e "$shared_link" ]]; then
        if diff -qr "$shared_target" "$shared_link" >/dev/null 2>&1; then
            rm -rf "$shared_link"
        else
            mv "$shared_link" "$backup"
            echo "[entrypoint] WARN: found diverged shared copy in $workspace; moved to $backup"
        fi
    fi

    if ln -s "$shared_target" "$shared_link" 2>/dev/null; then
        return 0
    fi

    if command -v cygpath >/dev/null 2>&1 && command -v cmd.exe >/dev/null 2>&1; then
        local win_link win_target
        win_link="$(cygpath -w "$shared_link")"
        win_target="$(cygpath -w "$shared_target")"
        cmd.exe /c mklink /J "$win_link" "$win_target" >/dev/null 2>&1 || true
        if [[ -e "$shared_link/manage_finance.py" ]]; then
            return 0
        fi
    fi

    echo "[entrypoint] WARN: failed to mount shared path for $workspace (link/junction)."
}

if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
    echo "[entrypoint] Writing openclaw.json..."
    # Use Python instead of sed to safely handle paths with special characters (|, spaces, etc.)
    python3 - <<PYEOF
src = open("$CORP_ROOT/openclaw.json").read()
dst = src.replace("PROFIT_CORP_ROOT", "$CORP_ROOT")
open("$OPENCLAW_CONFIG", "w").write(dst)
PYEOF

    if [[ -n "$TELEGRAM_CHAT_ID" ]]; then
        python3 - <<PYEOF
import json

cfg_path = "$OPENCLAW_CONFIG"
chat_id  = "$TELEGRAM_CHAT_ID"

with open(cfg_path) as f:
    cfg = json.load(f)

telegram = cfg.get("channels", {}).get("telegram", {})
allow_from = telegram.get("allowFrom", [])
if chat_id not in allow_from:
    allow_from.append(chat_id)
telegram["allowFrom"] = allow_from

with open(cfg_path, "w") as f:
    json.dump(cfg, f, indent=2)
PYEOF
        echo "[entrypoint] Telegram allowFrom: $TELEGRAM_CHAT_ID"
    fi
else
    echo "[entrypoint] openclaw.json already exists — skipping write."
fi

# ── Remove legacy 'main' default agent ────────────────────────────────────────
# Profit-corp designates CEO as the default agent. Any pre-existing 'main'
# agent must be removed so it cannot intercept unmatched messages.
echo "[entrypoint] Removing legacy 'main' default agent (if present)..."
openclaw agents remove main --force 2>/dev/null || true
MAIN_WORKSPACE="$STATE_DIR/agents/main"
if [[ -d "$MAIN_WORKSPACE" ]]; then
    echo "[entrypoint] Removing leftover main workspace: $MAIN_WORKSPACE"
    rm -rf "$MAIN_WORKSPACE"
fi
echo "[entrypoint] ✓ Default agent cleanup complete."
echo "[entrypoint] NOTE: after gateway is up, verify bindings with: openclaw agents list --bindings (telegram/webchat/webhook -> ceo)"

# ── Ensure each workspace can resolve shared/* paths ─────────────────────────
for agent in scout cmo arch ceo accountant; do
    ensure_workspace_shared_link "$CORP_ROOT/workspaces/$agent"
done

# ── Ensure archives directory exists ─────────────────────────────────────────
mkdir -p "$CORP_ROOT/archives"

# ── Initialise ledger ─────────────────────────────────────────────────────────
if [[ -f "$CORP_ROOT/shared/manage_finance.py" ]]; then
    echo "[entrypoint] Initialising ledger..."
    python3 "$CORP_ROOT/shared/manage_finance.py" audit || true
fi

# ── Runtime env diagnostics (non-secret) ─────────────────────────────────────
if [[ -n "${OPENAI_BASE_URL:-}" && -n "${OPENAI_API_KEY:-}" ]]; then
    echo "[entrypoint] Provider env detected: OPENAI-compatible (${OPENAI_BASE_URL})"
elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "[entrypoint] Provider env detected: ANTHROPIC_API_KEY"
elif [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    echo "[entrypoint] Provider env detected: OPENROUTER_API_KEY"
else
    echo "[entrypoint] WARNING: No provider API env detected. Check .env / compose env_file."
fi

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
    echo "[entrypoint] WARNING: TELEGRAM_BOT_TOKEN is missing in runtime env."
fi
if [[ -z "${OPENCLAW_HOOKS_TOKEN:-}" ]]; then
    echo "[entrypoint] WARNING: OPENCLAW_HOOKS_TOKEN is missing in runtime env."
fi

# ── Start OpenCLAW gateway in foreground ─────────────────────────────────────
echo "[entrypoint] Launching OpenCLAW gateway on port 18789..."
exec openclaw gateway --port 18789 --bind 0.0.0.0
