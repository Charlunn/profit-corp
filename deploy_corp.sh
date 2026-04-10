#!/bin/bash

# Profit-First SaaS Inc. - Cloud/Local Deployment Script
# -------------------------------------------------------
# This is the LEGACY one-step setup for environments that already have
# OpenCLAW installed. For a full native integration (cron, Telegram,
# webchat routing, no default agent), use the new setup script instead:
#
#   ./setup_corp.sh      ← recommended for existing OpenCLAW installs
#   docker-compose up -d ← recommended for fresh cloud servers
#
# See ARCHITECTURE.md for the full OpenCLAW integration guide.

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

# 3. Initialize Finance
echo "--- Initializing Ledger ---"
python3 "$CORP_ROOT/shared/manage_finance.py" audit

echo "✅ Deployment Complete."
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
