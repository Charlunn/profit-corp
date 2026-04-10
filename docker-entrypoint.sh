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

mkdir -p "$STATE_DIR"

# ── Write openclaw.json (on first run or if missing) ─────────────────────────
if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
    echo "[entrypoint] Writing openclaw.json..."
    sed "s|PROFIT_CORP_ROOT|$CORP_ROOT|g" "$CORP_ROOT/openclaw.json" > "$OPENCLAW_CONFIG"

    if [[ -n "$TELEGRAM_CHAT_ID" ]]; then
        sed -i "s|allowFrom: \[\]|allowFrom: [\"$TELEGRAM_CHAT_ID\"]|g" "$OPENCLAW_CONFIG"
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

# ── Ensure archives directory exists ─────────────────────────────────────────
mkdir -p "$CORP_ROOT/archives"

# ── Initialise ledger ─────────────────────────────────────────────────────────
if [[ -f "$CORP_ROOT/shared/manage_finance.py" ]]; then
    echo "[entrypoint] Initialising ledger..."
    python3 "$CORP_ROOT/shared/manage_finance.py" audit || true
fi

# ── Start OpenCLAW gateway in foreground ─────────────────────────────────────
echo "[entrypoint] Launching OpenCLAW gateway on port 18789..."
exec openclaw gateway --port 18789 --bind 0.0.0.0
