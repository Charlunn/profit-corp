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

ask_config_choice() {
    local ans
    while true; do
        read -r -p "Choose config action [O]verwrite [M]erge-update [S]kip (default: M): " ans
        ans="${ans:-M}"
        case "${ans^^}" in
            O|M|S) echo "${ans^^}"; return 0 ;;
            *) warn "Invalid choice: $ans" ;;
        esac
    done
}

ask_provider_choice() {
    local ans
    while true; do
        read -r -p "Select provider [1] newapi (default) [2] OpenAI [3] Anthropic [4] OpenRouter [5] Custom OpenAI-compatible: " ans
        ans="${ans:-1}"
        case "$ans" in
            1|2|3|4|5) echo "$ans"; return 0 ;;
            *) warn "Invalid choice: $ans" ;;
        esac
    done
}

upsert_env_var() {
    local env_file="$1"
    local key="$2"
    local value="$3"
    python3 - "$env_file" "$key" "$value" <<'PYEOF'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]
line = f"{key}={value}"
if not p.exists():
    p.write_text(line + "\n", encoding="utf-8")
    raise SystemExit(0)
text = p.read_text(encoding="utf-8")
lines = text.splitlines()
pat = re.compile(rf"^\s*{re.escape(key)}\s*=")
for i, l in enumerate(lines):
    if pat.match(l):
        lines[i] = line
        break
else:
    lines.append(line)
out = "\n".join(lines)
if text.endswith("\n") or not lines:
    out += "\n"
p.write_text(out, encoding="utf-8")
PYEOF
}

load_env_file() {
    local env_file="$1"
    local normalized="$OPENCLAW_CONFIG_DIR/.env.normalized"
    sed 's/\r$//' "$env_file" > "$normalized"
    set -a
    # shellcheck disable=SC1090
    source "$normalized"
    set +a
}

configure_api_provider() {
    local env_file="$1"

    if [[ -n "${OPENAI_API_KEY:-}" || -n "${ANTHROPIC_API_KEY:-}" || -n "${OPENROUTER_API_KEY:-}" ]]; then
        info "Detected existing provider configuration in .env"
        if confirm "Keep existing provider configuration (recommended)?"; then
            info "✓ Keeping existing provider configuration unchanged"
            return 0
        fi
    fi

    info "API provider setup"
    local choice
    choice=$(ask_provider_choice)

    case "$choice" in
        1)
            read -r -p "newapi base URL (OpenAI-compatible, e.g. https://<your-domain>/v1): " NEWAPI_BASE_URL
            read -r -p "newapi API key: " NEWAPI_API_KEY
            [[ -z "${NEWAPI_BASE_URL:-}" ]] && error "newapi base URL is required"
            [[ -z "${NEWAPI_API_KEY:-}" ]] && error "newapi API key is required"
            upsert_env_var "$env_file" "OPENAI_BASE_URL" "$NEWAPI_BASE_URL"
            upsert_env_var "$env_file" "OPENAI_API_KEY" "$NEWAPI_API_KEY"
            info "✓ Provider set to newapi (OPENAI_BASE_URL + OPENAI_API_KEY)"
            ;;
        2)
            read -r -p "OpenAI API key: " OPENAI_KEY
            [[ -z "${OPENAI_KEY:-}" ]] && error "OpenAI API key is required"
            upsert_env_var "$env_file" "OPENAI_API_KEY" "$OPENAI_KEY"
            info "✓ Provider set to OpenAI"
            ;;
        3)
            read -r -p "Anthropic API key: " ANTHROPIC_KEY
            [[ -z "${ANTHROPIC_KEY:-}" ]] && error "Anthropic API key is required"
            upsert_env_var "$env_file" "ANTHROPIC_API_KEY" "$ANTHROPIC_KEY"
            info "✓ Provider set to Anthropic"
            ;;
        4)
            read -r -p "OpenRouter API key: " OPENROUTER_KEY
            [[ -z "${OPENROUTER_KEY:-}" ]] && error "OpenRouter API key is required"
            upsert_env_var "$env_file" "OPENROUTER_API_KEY" "$OPENROUTER_KEY"
            info "✓ Provider set to OpenRouter"
            ;;
        5)
            read -r -p "Custom OpenAI-compatible base URL: " CUSTOM_BASE_URL
            read -r -p "Custom API key: " CUSTOM_API_KEY
            [[ -z "${CUSTOM_BASE_URL:-}" ]] && error "Custom base URL is required"
            [[ -z "${CUSTOM_API_KEY:-}" ]] && error "Custom API key is required"
            upsert_env_var "$env_file" "OPENAI_BASE_URL" "$CUSTOM_BASE_URL"
            upsert_env_var "$env_file" "OPENAI_API_KEY" "$CUSTOM_API_KEY"
            info "✓ Provider set to custom OpenAI-compatible endpoint"
            ;;
    esac
}

# ── Detect paths ─────────────────────────────────────────────────────────────
CORP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_CONFIG_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
OPENCLAW_CONFIG="$OPENCLAW_CONFIG_DIR/openclaw.json"
OPENCLAW_CONFIG_BACKUP="$OPENCLAW_CONFIG_DIR/openclaw.json.$(date +%Y%m%d_%H%M%S).bak"

mkdir -p "$OPENCLAW_CONFIG_DIR"

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
ENV_FILE="$CORP_ROOT/.env"
if [[ -f "$ENV_FILE" ]]; then
    info "Loading .env"
    load_env_file "$ENV_FILE"
else
    warn ".env not found. Creating a new one from .env.example ..."
    if [[ -f "$CORP_ROOT/.env.example" ]]; then
        cp "$CORP_ROOT/.env.example" "$ENV_FILE"
        info "✓ Created $ENV_FILE"
        load_env_file "$ENV_FILE"
    else
        error ".env.example not found. Cannot initialize environment."
    fi
fi

configure_api_provider "$ENV_FILE"
load_env_file "$ENV_FILE"

# ── Ensure ~/.openclaw dir exists ─────────────────────────────────────────────
mkdir -p "$OPENCLAW_CONFIG_DIR"

# ── Write openclaw.json ───────────────────────────────────────────────────────
OPENCLAW_TZ="${CORP_TIMEZONE:-UTC}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

info "Writing OpenCLAW configuration..."

# Backup existing config if present
CONFIG_ACTION="O"
if [[ -f "$OPENCLAW_CONFIG" ]]; then
    warn "Existing openclaw.json found at $OPENCLAW_CONFIG"
    CONFIG_ACTION=$(ask_config_choice)

    if [[ "$CONFIG_ACTION" != "S" ]]; then
        warn "Backing up existing config to $OPENCLAW_CONFIG_BACKUP"
        cp "$OPENCLAW_CONFIG" "$OPENCLAW_CONFIG_BACKUP"
    fi
fi

if [[ "$CONFIG_ACTION" == "S" ]]; then
    info "Skipping openclaw.json write/update by user choice."
else
    # Substitute PROFIT_CORP_ROOT and prepare template text
    TEMPLATE_CONFIG_PATH="$OPENCLAW_CONFIG_DIR/openclaw.template.json"
    python3 - <<PYEOF
src = open("$CORP_ROOT/openclaw.json").read()
dst = src.replace("PROFIT_CORP_ROOT", "$CORP_ROOT")
open("$TEMPLATE_CONFIG_PATH", "w").write(dst)
PYEOF

    if [[ "$CONFIG_ACTION" == "M" && -f "$OPENCLAW_CONFIG" ]]; then
        info "Merging required corp settings into existing openclaw.json..."
        python3 - <<PYEOF
import json

target_path = "$OPENCLAW_CONFIG"
template_path = "$TEMPLATE_CONFIG_PATH"

with open(template_path, "r", encoding="utf-8") as f:
    tpl = json.load(f)
with open(target_path, "r", encoding="utf-8") as f:
    cur = json.load(f)

cur.setdefault("agents", {})
cur["agents"]["defaults"] = tpl["agents"].get("defaults", {})
cur["agents"]["list"] = tpl["agents"].get("list", [])
cur["bindings"] = tpl.get("bindings", [])

# Keep existing telegram bot settings; only ensure allowFrom can be appended later.
cur.setdefault("channels", {})
if "telegram" not in cur["channels"]:
    cur["channels"]["telegram"] = tpl["channels"].get("telegram", {})

cur["tools"] = tpl.get("tools", {})
cur["cron"] = tpl.get("cron", {})
cur["hooks"] = tpl.get("hooks", {})
cur["session"] = tpl.get("session", {})
cur["gateway"] = tpl.get("gateway", {})

with open(target_path, "w", encoding="utf-8") as f:
    json.dump(cur, f, indent=2)
PYEOF
    else
        info "Writing OpenCLAW configuration (overwrite)..."
        cp "$TEMPLATE_CONFIG_PATH" "$OPENCLAW_CONFIG"
    fi

    rm -f "$TEMPLATE_CONFIG_PATH"
fi


# Inject numeric telegram chat ID into allowFrom if provided
if [[ -n "$TELEGRAM_CHAT_ID" ]]; then
    # Use Python to safely inject the chat ID into the JSON's allowFrom array.
    # This avoids sed delimiter conflicts and handles any path/ID format correctly.
    python3 - <<PYEOF
import json, sys

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
    info "Telegram allowFrom set to: $TELEGRAM_CHAT_ID"
fi

info "✓ Config written to $OPENCLAW_CONFIG"

# ── Preflight: normalize config and ensure gateway availability ───────────────
info "Running OpenCLAW config preflight..."
openclaw doctor --fix >/dev/null 2>&1 || true

OPENCLAW_PORT="${OPENCLAW_PORT:-18789}"
if ! openclaw agents list >/dev/null 2>&1; then
    warn "Gateway not reachable yet. Auto-starting gateway on port $OPENCLAW_PORT ..."
    nohup openclaw gateway --port "$OPENCLAW_PORT" >/tmp/openclaw-gateway.log 2>&1 &
    sleep 1
fi

# ── Remove legacy 'main' default agent ───────────────────────────────────────
# OpenCLAW's single-agent mode creates a "main" workspace/agent by default.
# Profit-corp uses CEO as the default; the 'main' agent must not exist or it
# will intercept unmatched messages and corrupt the org structure.
info "Removing legacy 'main' default agent (if present)..."

# Remove from OpenCLAW agent registry (idempotent — ignores errors if absent)
openclaw agents remove main --force 2>/dev/null || true

# Remove any leftover main workspace directory under the state dir
MAIN_WORKSPACE="$OPENCLAW_CONFIG_DIR/agents/main"
if [[ -d "$MAIN_WORKSPACE" ]]; then
    warn "Found leftover main workspace at $MAIN_WORKSPACE — removing..."
    rm -rf "$MAIN_WORKSPACE"
    info "✓ Legacy 'main' workspace removed."
else
    info "✓ No legacy 'main' workspace found (clean)."
fi


info "Registering corp agents with OpenCLAW..."

agents=(scout cmo arch ceo accountant)
for agent in "${agents[@]}"; do
    workspace="$CORP_ROOT/workspaces/$agent"
    info "  → Adding agent: $agent (workspace: $workspace)"

    # Treat "already exists" as success; only warn on real failures.
    out="$(openclaw agents add "$agent" --workspace "$workspace" --non-interactive 2>&1)" || rc=$?
    rc=${rc:-0}

    if [[ $rc -eq 0 ]]; then
        info "  ✓ Registered $agent"
    elif echo "$out" | grep -qi "already exists"; then
        info "  ✓ $agent already registered (skipped)"
    else
        warn "  ⚠ Could not register $agent"
        echo "$out" | sed 's/^/[corp]     /'
    fi
    unset rc
done

# ── Post-setup binding verification ───────────────────────────────────────────
info "Verifying CEO default routing bindings..."
BINDINGS_OUT="$(openclaw agents list --bindings 2>/dev/null || true)"
if echo "$BINDINGS_OUT" | grep -q "telegram.*ceo" && \
   echo "$BINDINGS_OUT" | grep -q "webchat.*ceo" && \
   echo "$BINDINGS_OUT" | grep -q "webhook.*ceo"; then
    info "✓ CEO bindings verified for telegram/webchat/webhook"
else
    warn "Could not confirm full CEO bindings from gateway output."
    warn "Run: openclaw agents list --bindings"
fi

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

# ── Initialise Ledger (idempotent reset) ──────────────────────────────────────
if [[ -n "$PYTHON_CMD" ]]; then
    info "Resetting company ledger to baseline..."
    $PYTHON_CMD "$CORP_ROOT/shared/manage_finance.py" reset "Profit-First SaaS Inc."
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
