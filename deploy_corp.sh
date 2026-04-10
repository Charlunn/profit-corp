#!/bin/bash

# =============================================================================
# ⚠️  DEPRECATED — DO NOT USE FOR NEW DEPLOYMENTS
# =============================================================================
# This script is kept for historical reference only.
#
# It does NOT configure:
#   - CEO as the default agent (main agent conflict)
#   - Telegram channel bindings
#   - Native cron scheduling
#   - openclaw.json gateway configuration
#   - RBAC sensitive-op gates
#
# Use one of the supported deployment methods instead:
#
#   ./setup_corp.sh      ← for existing OpenCLAW installations (recommended)
#   docker-compose up -d ← for fresh cloud servers / Docker environments
#
# See ARCHITECTURE.md for the full OpenCLAW integration guide.
# =============================================================================

echo "⚠️  WARNING: deploy_corp.sh is DEPRECATED."
echo "   Please use ./setup_corp.sh or docker-compose up -d instead."
echo ""
read -r -p "Continue anyway? [y/N] " ans
if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    echo "Aborted. Run ./setup_corp.sh for the recommended setup."
    exit 0
fi

echo "🚀 Deploying Profit-First SaaS Inc..."

# 1. Path detection
CORP_ROOT=$(cd "$(dirname "$0")" && pwd)

# Check if openclaw is available globally
if ! command -v openclaw &> /dev/null; then
    echo "⚠️ Warning: 'openclaw' command not found in PATH."
    echo "Attempting to fallback to local ../openclaw.mjs..."
    OPENCLAW_CMD="node ../openclaw.mjs"
else
    OPENCLAW_CMD="openclaw"
fi

# 2. Register agents using `openclaw agents add` (the correct modern command)
# Each agent gets its own isolated workspace, session store, and auth profile.
agents=("scout" "cmo" "arch" "ceo" "accountant")

for agent in "${agents[@]}"; do
    echo "--- Registering $agent ---"
    $OPENCLAW_CMD agents add "$agent" --workspace "$CORP_ROOT/workspaces/$agent" --non-interactive 2>/dev/null || \
    $OPENCLAW_CMD agent create "$agent" --workspace "$CORP_ROOT/workspaces/$agent" -y 2>/dev/null || \
    echo "  ⚠ Could not register $agent — start the gateway first, or use setup_corp.sh"
done

# NOTE: Ledger audit (manage_finance.py audit) is intentionally NOT called here.
# Running audit during deployment deducts 10 pts/agent from day-0 balances for no reason.
# The audit is triggered automatically by the daily cron job and by Accountant.

echo "✅ Deployment Complete (legacy mode)."
echo ""
echo "⚠️  For full OpenCLAW-native integration (Telegram, webchat, cron), run:"
echo "   ./setup_corp.sh"
echo ""
echo "Workflow (manual run):"
echo "1. Scout:      $OPENCLAW_CMD agent run scout 'Find leads'"
echo "2. CMO:        $OPENCLAW_CMD agent run cmo 'Make plan'"
echo "3. Arch:       $OPENCLAW_CMD agent run arch 'Design spec'"
echo "4. CEO:        $OPENCLAW_CMD agent run ceo 'Decision'"
echo "5. Auditor:    $OPENCLAW_CMD agent run accountant 'Audit'"
echo ""
echo "Or trigger via Telegram after running setup_corp.sh!"
