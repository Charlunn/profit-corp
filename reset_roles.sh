#!/usr/bin/env bash
set -euo pipefail

# Reset and re-register Profit-Corp agents without touching provider/bot config.
# Safe by default: only agent registry/workspace session dirs are affected.

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[reset]${NC} $*"; }
warn()  { echo -e "${YELLOW}[reset]${NC} $*"; }
error() { echo -e "${RED}[reset]${NC} $*" >&2; exit 1; }
confirm() { read -r -p "$1 [y/N] " ans; [[ "$ans" =~ ^[Yy]$ ]]; }

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
    tail -n 40 /tmp/openclaw-gateway.log | sed 's/^/[reset]   gateway | /'
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

CORP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"

if ! command -v openclaw >/dev/null 2>&1; then
  error "OpenCLAW not found. Install it first: npm install -g openclaw@latest"
fi

agents=(scout cmo arch ceo accountant)

info "Profit-Corp role reset"
info "Corp root: $CORP_ROOT"
info "State dir: $OPENCLAW_STATE_DIR"
warn "This script WILL NOT modify .env or provider/bot tokens."
warn "It only resets agent registrations and optionally clears agent session folders."

if ! confirm "Continue with role reset?"; then
  info "Cancelled."
  exit 0
fi

CLEAR_SESSIONS=false
if confirm "Also clear local agent session folders under $OPENCLAW_STATE_DIR/agents/* ?"; then
  CLEAR_SESSIONS=true
fi

OPENCLAW_PORT="${OPENCLAW_PORT:-18789}"
ensure_gateway_ready "$OPENCLAW_PORT" 30 1 || \
  error "Gateway is required for role reset. Fix the gateway error above and rerun."

info "Removing legacy 'main' agent if present..."
openclaw agents remove main --force >/dev/null 2>&1 || true

for agent in "${agents[@]}"; do
  info "Resetting agent: $agent"
  openclaw agents remove "$agent" --force >/dev/null 2>&1 || true

  if [[ "$CLEAR_SESSIONS" == true ]]; then
    agent_dir="$OPENCLAW_STATE_DIR/agents/$agent"
    if [[ -d "$agent_dir" ]]; then
      rm -rf "$agent_dir"
      info "  Cleared sessions: $agent_dir"
    fi
  fi

  workspace="$CORP_ROOT/workspaces/$agent"
  if [[ ! -d "$workspace" ]]; then
    error "Workspace missing for $agent: $workspace"
  fi
  ensure_workspace_shared_link "$workspace"

  rc=0
  out="$(openclaw agents add "$agent" --workspace "$workspace" --non-interactive 2>&1)" || rc=$?

  if [[ $rc -eq 0 ]]; then
    info "  Registered: $agent"
  elif echo "$out" | grep -qi "already exists"; then
    warn "  Agent '$agent' already exists; keeping existing registration."
  else
    echo "$out" | sed 's/^/[reset]   /'
    error "Failed to register $agent"
  fi
done

info "Verifying workspace shared links..."
for agent in "${agents[@]}"; do
  workspace="$CORP_ROOT/workspaces/$agent"
  ensure_workspace_shared_link "$workspace"
done

info "Verifying bindings..."
openclaw agents list --bindings || warn "Could not fetch bindings; ensure gateway is running"

info "✅ Role reset complete. Provider and bot config unchanged."
