#!/usr/bin/env bash
# install_extension.sh — Mode B: integrate profit-corp into an existing OpenCLAW install.
#
# Run this when you already have OpenCLAW deployed and just want to plug
# profit-corp in as an extension (agents + shared skills + cron).
#
# What this script does:
#   1. Detects your existing OpenCLAW config directory (~/.openclaw by default).
#   2. Merges the profit-corp agent definitions into openclaw.json via openclaw config set.
#   3. Copies shared/skills into ~/.openclaw/skills so all agents can use them.
#   4. Registers the daily workflow cron job via setup_cron.sh.
#
# Usage:
#   chmod +x install_extension.sh
#   TELEGRAM_OWNER_ID=<your_id> CORP_TZ=Asia/Shanghai ./install_extension.sh
#
# Environment variables:
#   OPENCLAW_CONFIG_DIR  — Override the OpenCLAW config dir (default: ~/.openclaw)
#   TELEGRAM_OWNER_ID    — Required: your numeric Telegram user ID
#   CORP_TZ              — Timezone for cron (default: UTC)

set -euo pipefail

OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$HOME/.openclaw}"
CORP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔌  profit-corp Extension Installer"
echo "   Corp root       : $CORP_ROOT"
echo "   OpenCLAW config : $OPENCLAW_CONFIG_DIR"

# Resolve the openclaw command.
if command -v openclaw &>/dev/null; then
  OC="openclaw"
elif [ -f "$CORP_ROOT/../openclaw.mjs" ]; then
  OC="node $CORP_ROOT/../openclaw.mjs"
else
  echo "❌  openclaw not found. Install it with: npm install -g openclaw@latest"
  exit 1
fi

# ── 1. Register agents ────────────────────────────────────────────────────────
echo ""
echo "1️⃣   Registering profit-corp agents in openclaw.json …"

for AGENT in scout cmo arch ceo accountant; do
  WORKSPACE="$CORP_ROOT/workspaces/$AGENT"
  echo "   → $AGENT (workspace: $WORKSPACE)"

  # openclaw config set writes directly into openclaw.json in the config dir.
  # Each agent entry is appended to agents.list[].
  $OC config set "agents.list" \
    --merge-item \
    --json "{\"id\":\"$AGENT\",\"workspace\":\"$WORKSPACE\"}" \
    2>/dev/null || {
      # Fallback: create or update via agents add command if available.
      $OC agents add "$AGENT" \
        --workspace "$WORKSPACE" \
        --non-interactive 2>/dev/null || true
    }
done

echo "   ✅  Agents registered."

# ── 2. Install shared skills ──────────────────────────────────────────────────
echo ""
echo "2️⃣   Installing shared skills into $OPENCLAW_CONFIG_DIR/skills …"

SKILLS_SRC="$CORP_ROOT/shared/skills"
SKILLS_DST="$OPENCLAW_CONFIG_DIR/skills"

if [ -d "$SKILLS_SRC" ]; then
  mkdir -p "$SKILLS_DST"
  cp -rn "$SKILLS_SRC/"* "$SKILLS_DST/" 2>/dev/null || true
  echo "   ✅  Skills copied to $SKILLS_DST"
else
  echo "   ℹ️   No shared/skills directory found — skipping."
fi

# ── 3. Merge Telegram custom commands ─────────────────────────────────────────
echo ""
echo "3️⃣   Adding profit-corp Telegram commands to openclaw.json …"

$OC config set "channels.telegram.customCommands" \
  --merge-item --json '{"command":"new_project","description":"Kick off a new project scan"}' \
  2>/dev/null || true
$OC config set "channels.telegram.customCommands" \
  --merge-item --json '{"command":"revenue","description":"Report revenue: /revenue <pts> <source>"}' \
  2>/dev/null || true
$OC config set "channels.telegram.customCommands" \
  --merge-item --json '{"command":"balance","description":"Show treasury & agent balances"}' \
  2>/dev/null || true
$OC config set "channels.telegram.customCommands" \
  --merge-item --json '{"command":"daily_run","description":"Trigger the full Daily Workflow now"}' \
  2>/dev/null || true
$OC config set "channels.telegram.customCommands" \
  --merge-item --json '{"command":"audit","description":"Run the Accountant financial audit"}' \
  2>/dev/null || true
$OC config set "channels.telegram.customCommands" \
  --merge-item --json '{"command":"archive","description":"Archive project: /archive <name>"}' \
  2>/dev/null || true

echo "   ✅  Telegram commands merged."

# ── 4. Register cron jobs ─────────────────────────────────────────────────────
echo ""
echo "4️⃣   Registering daily workflow cron …"

export CORP_TZ="${CORP_TZ:-UTC}"
export TELEGRAM_OWNER_ID="${TELEGRAM_OWNER_ID:-}"

if [ -z "$TELEGRAM_OWNER_ID" ]; then
  echo "   ⚠️   TELEGRAM_OWNER_ID not set — skipping cron registration."
  echo "   Run: TELEGRAM_OWNER_ID=<id> ./setup_cron.sh  to register cron later."
else
  bash "$CORP_ROOT/setup_cron.sh"
fi

# ── 5. Initialize finance ledger ──────────────────────────────────────────────
echo ""
echo "5️⃣   Initialising Ledger …"
python3 "$CORP_ROOT/shared/manage_finance.py" audit

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "🎉  profit-corp is now plugged into your OpenCLAW instance!"
echo ""
echo "Next steps:"
echo "  • Restart the gateway so agent changes take effect: $OC gateway restart"
echo "  • Open the Control UI: $OC dashboard"
echo "  • Or send a Telegram message to your bot to verify the connection."
