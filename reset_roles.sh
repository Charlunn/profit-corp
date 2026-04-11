#!/usr/bin/env bash
set -euo pipefail

# Reset and re-register Profit-Corp agents without touching provider/bot config.
# Safe by default: only agent registry/workspace session dirs are affected.

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[reset]${NC} $*"; }
warn()  { echo -e "${YELLOW}[reset]${NC} $*"; }
error() { echo -e "${RED}[reset]${NC} $*" >&2; exit 1; }
confirm() { read -r -p "$1 [y/N] " ans; [[ "$ans" =~ ^[Yy]$ ]]; }

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

  out="$(openclaw agents add "$agent" --workspace "$workspace" --non-interactive 2>&1)" || {
    echo "$out" | sed 's/^/[reset]   /'
    error "Failed to register $agent"
  }
done

info "Verifying bindings..."
openclaw agents list --bindings || warn "Could not fetch bindings; ensure gateway is running"

info "✅ Role reset complete. Provider and bot config unchanged."
