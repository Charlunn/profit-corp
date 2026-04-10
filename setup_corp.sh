#!/usr/bin/env bash
# =============================================================================
# Profit-Corp Setup Script — Mode B: Existing OpenCLAW Installation
# =============================================================================
# Use this when OpenCLAW is already installed on your machine or cloud server.
# This script:
#   1. Detects OpenCLAW and Python
#   2. Writes openclaw.json to ~/.openclaw/ (substituting the correct paths)
#   3. Registers all corp agents via `openclaw agents add`
#   4. Registers the native daily cron job via `openclaw cron add`
#   5. Initialises the Ledger
#   6. Verifies the setup with `openclaw agents list --bindings`
#
# Prerequisites:
#   - OpenCLAW installed: npm install -g openclaw@latest  (or pnpm/bun)
#   - OpenCLAW gateway running OR will be started after this script
#   - .env file with TELEGRAM_BOT_TOKEN and OPENCLAW_HOOKS_TOKEN set
#
# Usage:
#   cd /path/to/profit-corp
#   cp .env.example .env   # fill in tokens
#   chmod +x setup_corp.sh
#   ./setup_corp.sh
# =============================================================================

set -euo pipefail

# ── Helpers ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[corp]${NC} $*"; }
warn()    { echo -e "${YELLOW}[corp]${NC} $*"; }
error()   { echo -e "${RED}[corp]${NC} $*" >&2; exit 1; }
confirm() { read -r -p "$1 [y/N] " ans; [[ "$ans" =~ ^[Yy]$ ]]; }

# ── Detect paths ─────────────────────────────────────────────────────────────
CORP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_CONFIG_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
OPENCLAW_CONFIG="$OPENCLAW_CONFIG_DIR/openclaw.json"
OPENCLAW_CONFIG_BACKUP="$OPENCLAW_CONFIG_DIR/openclaw.json.pre-corp.bak"

info "Profit-First SaaS Inc. — Corp Setup"
info "Corp root : $CORP_ROOT"
info "OpenCLAW  : $OPENCLAW_CONFIG_DIR"

# ── Check for OpenCLAW ────────────────────────────────────────────────────────
if ! command -v openclaw &>/dev/null; then
    error "OpenCLAW not found. Install it: npm install -g openclaw@latest"
fi
OPENCLAW_VERSION=$(openclaw --version 2>/dev/null || echo "unknown")
info "OpenCLAW version: $OPENCLAW_VERSION"

# ── Check for Python ─────────────────────────────────────────────────────────
PYTHON_CMD=""
for py in python3 python; do
    if command -v "$py" &>/dev/null; then
        PYTHON_CMD="$py"
        break
    fi
done
if [[ -z "$PYTHON_CMD" ]]; then
    warn "Python not found — Ledger initialisation will be skipped."
fi

# ── Load .env if present ─────────────────────────────────────────────────────
if [[ -f "$CORP_ROOT/.env" ]]; then
    info "Loading .env"
    set -a; source "$CORP_ROOT/.env"; set +a
else
    warn ".env not found. Telegram + webhook tokens must be set in ~/.openclaw/openclaw.json manually."
fi

# ── Ensure ~/.openclaw dir exists ─────────────────────────────────────────────
mkdir -p "$OPENCLAW_CONFIG_DIR"

# ── Write openclaw.json ───────────────────────────────────────────────────────
OPENCLAW_TZ="${CORP_TIMEZONE:-UTC}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

info "Writing OpenCLAW configuration..."

# Backup existing config if present
if [[ -f "$OPENCLAW_CONFIG" ]]; then
    warn "Existing openclaw.json found — backing up to $OPENCLAW_CONFIG_BACKUP"
    cp "$OPENCLAW_CONFIG" "$OPENCLAW_CONFIG_BACKUP"
fi

# Substitute PROFIT_CORP_ROOT and write config
sed "s|PROFIT_CORP_ROOT|$CORP_ROOT|g" "$CORP_ROOT/openclaw.json" > "$OPENCLAW_CONFIG"

# Append numeric telegram chat ID if provided
if [[ -n "$TELEGRAM_CHAT_ID" ]]; then
    # Update allowFrom in the config (simple sed replacement on the placeholder)
    sed -i "s|allowFrom: \[\]|allowFrom: [\"$TELEGRAM_CHAT_ID\"]|g" "$OPENCLAW_CONFIG"
    info "Telegram allowFrom set to: $TELEGRAM_CHAT_ID"
fi

info "✓ Config written to $OPENCLAW_CONFIG"

# ── Register agents ───────────────────────────────────────────────────────────
info "Registering corp agents with OpenCLAW..."

agents=(scout cmo arch ceo accountant)
for agent in "${agents[@]}"; do
    workspace="$CORP_ROOT/workspaces/$agent"
    info "  → Adding agent: $agent (workspace: $workspace)"
    # `openclaw agents add` is idempotent — re-running is safe
    openclaw agents add "$agent" --workspace "$workspace" --non-interactive || \
        warn "  ⚠ Could not register $agent — gateway may not be running yet. Run after starting: openclaw gateway"
done

# ── Register daily cron job ───────────────────────────────────────────────────
info "Registering native daily pipeline cron job (08:00 $OPENCLAW_TZ)..."

if [[ -n "$TELEGRAM_CHAT_ID" ]]; then
    CRON_DELIVER="--announce --channel telegram --to \"$TELEGRAM_CHAT_ID\""
else
    CRON_DELIVER=""
    warn "TELEGRAM_CHAT_ID not set — cron job will run silently (no Telegram delivery)."
fi

# Check if the cron job already exists
if openclaw cron list 2>/dev/null | grep -q "Daily SaaS Incubator"; then
    warn "Cron job 'Daily SaaS Incubator' already exists — skipping. Use: openclaw cron list"
else
    CRON_MSG="Good morning! Run the full daily pipeline:
1. Use sessions_spawn to ask Scout to scan for SaaS leads (blogwatcher, xurl).
2. Use sessions_spawn to ask CMO to analyse the top lead and draft a market plan.
3. Use sessions_spawn to ask Arch to write the tech spec.
4. Make your GO/NO-GO decision.
5. Use sessions_spawn to ask Accountant to run the daily audit.
Deliver a concise executive summary of the outcome to this Telegram chat."

    # shellcheck disable=SC2086
    openclaw cron add \
        --name "Daily SaaS Incubator" \
        --cron "0 8 * * *" \
        --tz "$OPENCLAW_TZ" \
        --agent ceo \
        --session isolated \
        --message "$CRON_MSG" \
        $CRON_DELIVER \
        2>/dev/null || warn "Could not register cron job — gateway may not be running yet."
fi

# ── Initialise Ledger ─────────────────────────────────────────────────────────
if [[ -n "$PYTHON_CMD" ]]; then
    info "Initialising company ledger..."
    $PYTHON_CMD "$CORP_ROOT/shared/manage_finance.py" audit
fi

# ── Verify ────────────────────────────────────────────────────────────────────
info "Verifying setup..."
openclaw agents list --bindings 2>/dev/null || \
    warn "Could not verify agents — start the gateway first: openclaw gateway --port 18789"
openclaw cron list 2>/dev/null || true

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅  Profit-Corp setup complete!                              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Next steps:"
echo "  1. Start the gateway (if not running):   openclaw gateway --port 18789"
echo "  2. Approve your Telegram DM:             openclaw pairing list telegram"
echo "                                            openclaw pairing approve telegram <CODE>"
echo "  3. Verify agent bindings:                openclaw agents list --bindings"
echo "  4. Run the daily pipeline manually:      openclaw cron run 'Daily SaaS Incubator'"
echo "  5. Open the Control UI:                  http://127.0.0.1:18789"
echo ""
echo "  OpenCLAW docs: https://docs.openclaw.ai"
