#!/usr/bin/env bash
# setup_cron.sh — Register the daily 08:00 workflow via OpenCLAW's native cron.
#
# Run this ONCE after deploying profit-corp (either Mode A Docker or Mode B Extension).
# The cron jobs persist in ~/.openclaw/cron/jobs.json and survive gateway restarts.
#
# Usage:
#   chmod +x setup_cron.sh
#   ./setup_cron.sh
#
# Required env vars (set in .env or export before running):
#   TELEGRAM_OWNER_ID  — Your numeric Telegram user ID
#   CORP_TZ            — Your timezone, e.g. "Asia/Shanghai" (defaults to UTC)
#
# Docs: https://docs.openclaw.ai/automation/cron-jobs

set -euo pipefail

CORP_TZ="${CORP_TZ:-UTC}"
OWNER_ID="${TELEGRAM_OWNER_ID:-}"

if [ -z "$OWNER_ID" ]; then
  echo "❌  TELEGRAM_OWNER_ID is not set. Export it before running this script."
  exit 1
fi

# Resolve the openclaw command (global install or local fallback).
if command -v openclaw &>/dev/null; then
  OC="openclaw"
elif [ -f "../openclaw.mjs" ]; then
  OC="node ../openclaw.mjs"
else
  echo "❌  openclaw not found. Install it with: npm install -g openclaw@latest"
  exit 1
fi

echo "🕗  Registering daily workflow cron (08:00 ${CORP_TZ}) …"

# ── Daily Workflow Job ──────────────────────────────────────────────────────
# Uses a named custom session ("session:daily-workflow") so previous context
# accumulates across days, giving the orchestrating CEO full historical memory.
# The CEO agent will read the shared global_state.json and the last PAIN_POINTS,
# then sequentially invoke Scout, CMO, Arch, and finally trigger Accountant.
$OC cron add \
  --name "daily-workflow" \
  --cron "0 8 * * *" \
  --tz "$CORP_TZ" \
  --session "session:daily-workflow" \
  --agentId "ceo" \
  --message "DAILY WORKFLOW START — Today's date: $(date +%Y-%m-%d).

Please orchestrate the full daily pipeline in order:
1. Instruct Scout (agentId: scout) to scan for at least 3 SaaS leads and write shared/PAIN_POINTS.md.
2. Instruct CMO (agentId: cmo) to pick the best lead and write shared/MARKET_PLAN.md.
3. Instruct Architect (agentId: arch) to design the tech spec and write shared/TECH_SPEC.md.
4. Make your own Greenlight/Veto decision and write your reasoning to shared/CEO_DECISION.md.
5. Instruct Accountant (agentId: accountant) to run the daily audit.

After all steps are done, send me a concise summary of:
- Today's chosen lead and decision
- Treasury status
- Any bankruptcy alerts

Keep the summary under 400 words." \
  --announce \
  --channel telegram \
  --to "$OWNER_ID"

echo "✅  daily-workflow cron registered."

# ── Weekly Archive Job ───────────────────────────────────────────────────────
# Every Sunday at 20:00 the CEO archives completed projects into archives/.
$OC cron add \
  --name "weekly-archive" \
  --cron "0 20 * * 0" \
  --tz "$CORP_TZ" \
  --session isolated \
  --agentId "accountant" \
  --message "Run weekly archiving: for every project listed in shared/CEO_DECISION.md that was Greenlighted and is now completed or vetoed, call: python3 shared/context_manager.py archive <project_name>. Then send me a brief archive report." \
  --announce \
  --channel telegram \
  --to "$OWNER_ID"

echo "✅  weekly-archive cron registered."

echo ""
echo "📋  Current cron jobs:"
$OC cron list
