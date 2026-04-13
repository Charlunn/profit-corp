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

ask_model_config_mode() {
    local ans
    while true; do
        read -r -p "Model config [1] one model for all agents (default) [2] choose per agent [3] keep current model config: " ans
        ans="${ans:-1}"
        case "$ans" in
            1|2|3) echo "$ans"; return 0 ;;
            *) warn "Invalid choice: $ans" ;;
        esac
    done
}

ask_yes_no_default() {
    local prompt="$1"
    local default="${2:-N}"
    local ans
    while true; do
        if [[ "${default^^}" == "Y" ]]; then
            read -r -p "$prompt [Y/n] " ans
            ans="${ans:-Y}"
        else
            read -r -p "$prompt [y/N] " ans
            ans="${ans:-N}"
        fi
        case "${ans^^}" in
            Y|N) [[ "${ans^^}" == "Y" ]]; return 0 ;;
            *) warn "Invalid choice: $ans" ;;
        esac
    done
}

prompt_secret() {
    local prompt="$1"
    local __var_name="$2"
    local value
    read -r -s -p "$prompt" value
    echo
    printf -v "$__var_name" '%s' "$value"
}

has_real_value() {
    local value="${1:-}"
    case "$value" in
        ""|your_newapi_api_key_here|your_telegram_bot_token_here|your_numeric_telegram_id_here|replace_with_strong_random_token|your_anthropic_api_key_here|your_openrouter_api_key_here|your_openai_api_key_here|your_custom_api_key_here|https://your-newapi-domain/v1|https://your-openai-compatible-domain/v1)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
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

unset_env_var() {
    local env_file="$1"
    local key="$2"
    python3 - "$env_file" "$key" <<'PYEOF'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
key = sys.argv[2]
if not p.exists():
    raise SystemExit(0)
text = p.read_text(encoding="utf-8")
lines = text.splitlines()
pat = re.compile(rf"^\s*{re.escape(key)}\s*=")
filtered = [line for line in lines if not pat.match(line)]
out = "\n".join(filtered)
if filtered and text.endswith("\n"):
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

clear_provider_env_vars() {
    local env_file="$1"
    unset_env_var "$env_file" "OPENAI_BASE_URL"
    unset_env_var "$env_file" "OPENAI_API_KEY"
    unset_env_var "$env_file" "ANTHROPIC_API_KEY"
    unset_env_var "$env_file" "OPENROUTER_API_KEY"
}

detect_provider_from_env() {
    CURRENT_PROVIDER_KIND=""
    CURRENT_PROVIDER_PREFIX=""
    CURRENT_PROVIDER_LABEL=""
    CURRENT_PROVIDER_BASE_URL=""
    CURRENT_PROVIDER_API_KEY=""

    if has_real_value "${OPENAI_API_KEY:-}"; then
        CURRENT_PROVIDER_KIND="openai-compatible"
        CURRENT_PROVIDER_PREFIX="openai"
        CURRENT_PROVIDER_API_KEY="${OPENAI_API_KEY}"
        if has_real_value "${OPENAI_BASE_URL:-}"; then
            CURRENT_PROVIDER_BASE_URL="${OPENAI_BASE_URL}"
            CURRENT_PROVIDER_LABEL="OpenAI-compatible"
        else
            CURRENT_PROVIDER_BASE_URL="https://api.openai.com/v1"
            CURRENT_PROVIDER_LABEL="OpenAI"
        fi
    elif has_real_value "${ANTHROPIC_API_KEY:-}"; then
        CURRENT_PROVIDER_KIND="anthropic"
        CURRENT_PROVIDER_PREFIX="anthropic"
        CURRENT_PROVIDER_LABEL="Anthropic"
        CURRENT_PROVIDER_BASE_URL="https://api.anthropic.com/v1"
        CURRENT_PROVIDER_API_KEY="${ANTHROPIC_API_KEY}"
    elif has_real_value "${OPENROUTER_API_KEY:-}"; then
        CURRENT_PROVIDER_KIND="openrouter"
        CURRENT_PROVIDER_PREFIX="openrouter"
        CURRENT_PROVIDER_LABEL="OpenRouter"
        CURRENT_PROVIDER_BASE_URL="https://openrouter.ai/api/v1"
        CURRENT_PROVIDER_API_KEY="${OPENROUTER_API_KEY}"
    fi
}

is_gateway_ready() {
    openclaw agents list >/dev/null 2>&1
}

start_gateway_if_needed() {
    local port="$1"
    if is_gateway_ready; then
        return 0
    fi
    warn "Gateway not reachable yet. Auto-starting gateway on port $port ..."
    nohup openclaw gateway --port "$port" >/tmp/openclaw-gateway.log 2>&1 &
}

wait_for_gateway_ready() {
    local timeout_s="$1"
    local interval_s="$2"
    local elapsed=0

    while (( elapsed < timeout_s )); do
        if is_gateway_ready; then
            return 0
        fi
        sleep "$interval_s"
        elapsed=$((elapsed + interval_s))
    done

    return 1
}

ensure_gateway_ready() {
    local port="$1"
    local timeout_s="${2:-30}"
    local interval_s="${3:-1}"

    start_gateway_if_needed "$port"
    if wait_for_gateway_ready "$timeout_s" "$interval_s"; then
        return 0
    fi

    warn "Gateway did not become ready within ${timeout_s}s."
    if [[ -f /tmp/openclaw-gateway.log ]]; then
        warn "Recent gateway log tail:"
        tail -n 40 /tmp/openclaw-gateway.log | sed 's/^/[corp]   gateway | /'
    else
        warn "Gateway log not found at /tmp/openclaw-gateway.log"
    fi
    return 1
}

ensure_workspace_shared_link() {
    local workspace="$1"
    local shared_target="$CORP_ROOT/shared"
    local shared_link="$workspace/shared"
    local backup="${shared_link}.bak.$(date +%Y%m%d_%H%M%S)"

    if [[ ! -d "$workspace" ]]; then
        warn "Workspace missing, cannot wire shared link: $workspace"
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
            warn "Found diverged shared copy in $workspace; moved to $backup"
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

    warn "Failed to mount shared path for $workspace (link/junction)."
}

configure_api_provider() {
    local env_file="$1"
    detect_provider_from_env

    if [[ -n "${CURRENT_PROVIDER_KIND:-}" ]]; then
        info "Detected existing provider configuration in .env (${CURRENT_PROVIDER_LABEL})"
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
            clear_provider_env_vars "$env_file"
            read -r -p "newapi base URL (OpenAI-compatible, e.g. https://<your-domain>/v1): " NEWAPI_BASE_URL
            prompt_secret "newapi API key: " NEWAPI_API_KEY
            [[ -z "${NEWAPI_BASE_URL:-}" ]] && error "newapi base URL is required"
            [[ -z "${NEWAPI_API_KEY:-}" ]] && error "newapi API key is required"
            upsert_env_var "$env_file" "OPENAI_BASE_URL" "$NEWAPI_BASE_URL"
            upsert_env_var "$env_file" "OPENAI_API_KEY" "$NEWAPI_API_KEY"
            info "✓ Provider set to newapi (OPENAI_BASE_URL + OPENAI_API_KEY)"
            ;;
        2)
            clear_provider_env_vars "$env_file"
            prompt_secret "OpenAI API key: " OPENAI_KEY
            [[ -z "${OPENAI_KEY:-}" ]] && error "OpenAI API key is required"
            upsert_env_var "$env_file" "OPENAI_API_KEY" "$OPENAI_KEY"
            info "✓ Provider set to OpenAI"
            ;;
        3)
            clear_provider_env_vars "$env_file"
            prompt_secret "Anthropic API key: " ANTHROPIC_KEY
            [[ -z "${ANTHROPIC_KEY:-}" ]] && error "Anthropic API key is required"
            upsert_env_var "$env_file" "ANTHROPIC_API_KEY" "$ANTHROPIC_KEY"
            info "✓ Provider set to Anthropic"
            ;;
        4)
            clear_provider_env_vars "$env_file"
            prompt_secret "OpenRouter API key: " OPENROUTER_KEY
            [[ -z "${OPENROUTER_KEY:-}" ]] && error "OpenRouter API key is required"
            upsert_env_var "$env_file" "OPENROUTER_API_KEY" "$OPENROUTER_KEY"
            info "✓ Provider set to OpenRouter"
            ;;
        5)
            clear_provider_env_vars "$env_file"
            read -r -p "Custom OpenAI-compatible base URL: " CUSTOM_BASE_URL
            prompt_secret "Custom API key: " CUSTOM_API_KEY
            [[ -z "${CUSTOM_BASE_URL:-}" ]] && error "Custom base URL is required"
            [[ -z "${CUSTOM_API_KEY:-}" ]] && error "Custom API key is required"
            upsert_env_var "$env_file" "OPENAI_BASE_URL" "$CUSTOM_BASE_URL"
            upsert_env_var "$env_file" "OPENAI_API_KEY" "$CUSTOM_API_KEY"
            info "✓ Provider set to custom OpenAI-compatible endpoint"
            ;;
    esac
}

fetch_provider_models() {
    local provider_kind="$1"
    local provider_prefix="$2"
    local base_url="$3"
    local api_key="$4"

    "$PYTHON_CMD" - "$provider_kind" "$provider_prefix" "$base_url" "$api_key" <<'PYEOF'
import json
import sys
import urllib.request

provider_kind, provider_prefix, base_url, api_key = sys.argv[1:]

if provider_kind == "anthropic":
    url = "https://api.anthropic.com/v1/models"
    headers = {
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
    }
else:
    base = (base_url or "").rstrip("/")
    url = base + "/models"
    headers = {"Authorization": f"Bearer {api_key}"}
    if provider_kind == "openrouter":
        headers["HTTP-Referer"] = "https://github.com/profit-corp/profit-corp"
        headers["X-Title"] = "Profit-Corp Setup"

req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req, timeout=30) as resp:
    payload = json.load(resp)

items = payload.get("data", [])
seen = set()
for item in items:
    model_id = ""
    if isinstance(item, dict):
        model_id = item.get("id") or item.get("name") or ""
    if not model_id:
        continue
    ref = f"{provider_prefix}/{model_id}"
    if ref in seen:
        continue
    seen.add(ref)
    print(ref)
PYEOF
}

print_model_catalog() {
    local -n models_ref=$1
    local count="${#models_ref[@]}"
    local i
    info "Available models discovered: $count"
    for ((i = 0; i < count; i++)); do
        printf '[corp]   %3d. %s\n' "$((i + 1))" "${models_ref[$i]}"
    done
}

resolve_model_choice() {
    local prompt="$1"
    local provider_prefix="$2"
    local -n models_ref=$3
    local ans candidate i

    while true; do
        read -r -p "$prompt (number or model id/ref): " ans
        [[ -z "$ans" ]] && { warn "A model choice is required."; continue; }

        if [[ "$ans" =~ ^[0-9]+$ ]]; then
            if (( ans >= 1 && ans <= ${#models_ref[@]} )); then
                echo "${models_ref[$((ans - 1))]}"
                return 0
            fi
            warn "Index out of range: $ans"
            continue
        fi

        if [[ "$ans" == */* ]]; then
            candidate="$ans"
        else
            candidate="${provider_prefix}/${ans}"
        fi

        for ((i = 0; i < ${#models_ref[@]}; i++)); do
            if [[ "${models_ref[$i]}" == "$candidate" ]]; then
                echo "$candidate"
                return 0
            fi
        done

        if ask_yes_no_default "Model '$candidate' was not returned by the provider. Use it anyway?" "N"; then
            echo "$candidate"
            return 0
        fi
    done
}

collect_model_configuration() {
    MODEL_CONFIG_MODE="keep"
    MODEL_CATALOG_MODE="selected"
    MODEL_DEFAULT_PRIMARY=""
    MODEL_CATALOG_FILE="$OPENCLAW_CONFIG_DIR/model-catalog.txt"
    : > "$MODEL_CATALOG_FILE"
    declare -gA MODEL_AGENT_SELECTIONS=()

    detect_provider_from_env
    if [[ -z "$CURRENT_PROVIDER_KIND" ]]; then
        warn "No active provider credentials found. Skipping model configuration."
        return 0
    fi

    local model_mode
    model_mode="$(ask_model_config_mode)"
    if [[ "$model_mode" == "3" ]]; then
        info "Keeping existing agent model configuration."
        return 0
    fi

    local fetch_err model_output fetch_rc
    fetch_err="$(mktemp)"
    model_output="$(fetch_provider_models "$CURRENT_PROVIDER_KIND" "$CURRENT_PROVIDER_PREFIX" "$CURRENT_PROVIDER_BASE_URL" "$CURRENT_PROVIDER_API_KEY" 2>"$fetch_err")" || fetch_rc=$?
    fetch_rc="${fetch_rc:-0}"
    if [[ "$fetch_rc" -ne 0 ]]; then
        warn "Could not fetch provider models automatically."
        sed 's/^/[corp]     /' "$fetch_err" >&2 || true
        AVAILABLE_MODELS=()
    elif [[ -n "$model_output" ]]; then
        mapfile -t AVAILABLE_MODELS <<< "$model_output"
    else
        AVAILABLE_MODELS=()
    fi
    rm -f "$fetch_err"

    if [[ ${#AVAILABLE_MODELS[@]} -gt 0 ]]; then
        print_model_catalog AVAILABLE_MODELS
    else
        warn "Falling back to manual model entry because no catalog was returned."
        AVAILABLE_MODELS=("${CURRENT_PROVIDER_PREFIX}/manual-placeholder")
    fi

    if ask_yes_no_default "Write the full fetched model catalog into OpenCLAW's allowlist?" "N"; then
        MODEL_CATALOG_MODE="full"
    fi

    local agents=(ceo scout cmo arch accountant)
    local choice selected agent
    if [[ "$model_mode" == "1" ]]; then
        choice="$(resolve_model_choice "Choose the default model for all agents" "$CURRENT_PROVIDER_PREFIX" AVAILABLE_MODELS)"
        MODEL_CONFIG_MODE="all"
        MODEL_DEFAULT_PRIMARY="$choice"
        for agent in "${agents[@]}"; do
            MODEL_AGENT_SELECTIONS["$agent"]="$choice"
        done
    else
        MODEL_CONFIG_MODE="per-agent"
        for agent in "${agents[@]}"; do
            selected="$(resolve_model_choice "Choose the default model for $agent" "$CURRENT_PROVIDER_PREFIX" AVAILABLE_MODELS)"
            MODEL_AGENT_SELECTIONS["$agent"]="$selected"
            [[ -z "$MODEL_DEFAULT_PRIMARY" ]] && MODEL_DEFAULT_PRIMARY="$selected"
        done
    fi

    if [[ "$MODEL_CATALOG_MODE" == "full" && ${#AVAILABLE_MODELS[@]} -gt 0 ]]; then
        printf '%s\n' "${AVAILABLE_MODELS[@]}" > "$MODEL_CATALOG_FILE"
    else
        printf '%s\n' "${MODEL_AGENT_SELECTIONS[@]}" | "$PYTHON_CMD" - <<'PYEOF' > "$MODEL_CATALOG_FILE"
import sys
seen = set()
for line in sys.stdin:
    model = line.strip()
    if not model or model in seen:
        continue
    seen.add(model)
    print(model)
PYEOF
    fi
}

apply_model_configuration() {
    local config_path="$1"

    [[ "${MODEL_CONFIG_MODE:-keep}" == "keep" ]] && return 0
    [[ ! -f "$config_path" ]] && return 0

    MODEL_DEFAULT_PRIMARY="${MODEL_DEFAULT_PRIMARY:-}"
    MODEL_CATALOG_FILE="${MODEL_CATALOG_FILE:-}"
    CEO_MODEL="${MODEL_AGENT_SELECTIONS[ceo]:-}"
    SCOUT_MODEL="${MODEL_AGENT_SELECTIONS[scout]:-}"
    CMO_MODEL="${MODEL_AGENT_SELECTIONS[cmo]:-}"
    ARCH_MODEL="${MODEL_AGENT_SELECTIONS[arch]:-}"
    ACCOUNTANT_MODEL="${MODEL_AGENT_SELECTIONS[accountant]:-}"
    export MODEL_CONFIG_MODE MODEL_DEFAULT_PRIMARY MODEL_CATALOG_FILE
    export CEO_MODEL SCOUT_MODEL CMO_MODEL ARCH_MODEL ACCOUNTANT_MODEL

    "$PYTHON_CMD" - "$config_path" <<'PYEOF'
import json
import os
import sys

config_path = sys.argv[1]
mode = os.environ.get("MODEL_CONFIG_MODE", "keep")
if mode == "keep":
    raise SystemExit(0)

with open(config_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

catalog_path = os.environ.get("MODEL_CATALOG_FILE", "")
catalog = []
if catalog_path and os.path.exists(catalog_path):
    with open(catalog_path, "r", encoding="utf-8") as f:
        catalog = [line.strip() for line in f if line.strip()]

agents = cfg.setdefault("agents", {})
defaults = agents.setdefault("defaults", {})
primary = os.environ.get("MODEL_DEFAULT_PRIMARY", "").strip()
if primary:
    defaults["model"] = {"primary": primary}

if catalog:
    defaults["models"] = {ref: {} for ref in catalog}
else:
    defaults.pop("models", None)

per_agent = {
    "ceo": os.environ.get("CEO_MODEL", "").strip(),
    "scout": os.environ.get("SCOUT_MODEL", "").strip(),
    "cmo": os.environ.get("CMO_MODEL", "").strip(),
    "arch": os.environ.get("ARCH_MODEL", "").strip(),
    "accountant": os.environ.get("ACCOUNTANT_MODEL", "").strip(),
}

for agent in agents.get("list", []):
    agent_id = agent.get("id")
    if mode == "all":
        agent.pop("model", None)
        continue
    selected = per_agent.get(agent_id, "")
    if selected:
        agent["model"] = {"primary": selected}
    else:
        agent.pop("model", None)

with open(config_path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF
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
collect_model_configuration

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
if [[ "$CONFIG_ACTION" == "S" ]]; then
    if [[ "${MODEL_CONFIG_MODE:-keep}" != "keep" ]]; then
        warn "Model configuration changes were collected but openclaw.json write was skipped, so they were not applied."
    fi
else
    apply_model_configuration "$OPENCLAW_CONFIG"
fi

info "Running OpenCLAW config preflight..."
openclaw doctor --fix >/dev/null 2>&1 || true

OPENCLAW_PORT="${OPENCLAW_PORT:-18789}"
ensure_gateway_ready "$OPENCLAW_PORT" 30 1 || \
    error "Gateway is required for agent registration. Fix the gateway error above and rerun."

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
    ensure_workspace_shared_link "$workspace"
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
    if [[ $rc -ne 0 ]] && echo "$out" | grep -qi "already exists"; then
        warn "    Existing agent IDs are not re-bound automatically. If workspace path/meta changed, run ./reset_roles.sh"
    fi
    unset rc
done

# ── Post-setup binding verification ───────────────────────────────────────────
info "Verifying CEO default routing bindings..."
BINDINGS_OUT="$(openclaw agents list --bindings 2>/dev/null || true)"
missing_bindings=()

if ! echo "$BINDINGS_OUT" | grep -Eiq 'telegram.*ceo|ceo.*telegram'; then
    missing_bindings+=("telegram -> ceo")
fi
if ! echo "$BINDINGS_OUT" | grep -Eiq 'webchat.*ceo|ceo.*webchat'; then
    missing_bindings+=("webchat -> ceo")
fi
if ! echo "$BINDINGS_OUT" | grep -Eiq 'webhook.*ceo|ceo.*webhook'; then
    missing_bindings+=("webhook -> ceo")
fi

if [[ ${#missing_bindings[@]} -eq 0 ]]; then
    info "✓ CEO bindings verified for telegram/webchat/webhook"
else
    warn "Could not confirm all CEO bindings. Missing: ${missing_bindings[*]}"
    warn "Run: openclaw agents list --bindings"
fi

info "Verifying workspace shared links..."
for agent in "${agents[@]}"; do
    workspace="$CORP_ROOT/workspaces/$agent"
    ensure_workspace_shared_link "$workspace"
done

# ── Register daily cron job ───────────────────────────────────────────────────
info "Registering native daily pipeline cron job (08:00 $OPENCLAW_TZ)..."

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
Deliver a concise executive summary of the outcome to this Telegram chat.
Use Simplified Chinese unless the shareholder explicitly asks for another language."

    cron_args=(
        --name "Daily SaaS Incubator"
        --cron "0 8 * * *"
        --tz "$OPENCLAW_TZ"
        --agent ceo
        --session isolated
        --message "$CRON_MSG"
    )

    if [[ -n "$TELEGRAM_CHAT_ID" ]]; then
        cron_args+=(--announce --channel telegram --to "$TELEGRAM_CHAT_ID")
    else
        warn "TELEGRAM_CHAT_ID not set — cron job will run silently (no Telegram delivery)."
    fi

    ensure_gateway_ready "$OPENCLAW_PORT" 30 1 || \
        error "Gateway is required for cron registration. Fix the gateway error above and rerun."
    cron_out="$(openclaw cron add "${cron_args[@]}" 2>&1)" || cron_rc=$?
    cron_rc=${cron_rc:-0}
    if [[ $cron_rc -ne 0 ]]; then
        warn "Could not register cron job. Check the error details below:"
        echo "$cron_out" | sed 's/^/[corp]     /'
        warn "Run: openclaw cron list"
    fi
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
