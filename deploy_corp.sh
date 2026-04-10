#!/bin/bash

# Profit-First SaaS Inc. - Cloud/Local Deployment Script
# This script registers all agents and prepares the workspace.

echo "🚀 Deploying Profit-First SaaS Inc..."

# 1. Path detection
# Assuming the script is run from the profit-corp root
CORP_ROOT=$(pwd)

# Check if openclaw is available globally
if ! command -v openclaw &> /dev/null; then
    echo "⚠️ Warning: 'openclaw' command not found in PATH."
    echo "Attempting to fallback to local ../openclaw.mjs..."
    OPENCLAW_CMD="node ../openclaw.mjs"
else
    OPENCLAW_CMD="openclaw"
fi

# 2. Register agents
# We use the local config logic
agents=("scout" "cmo" "arch" "ceo" "accountant")

for agent in "${agents[@]}"; do
    echo "--- Registering $agent ---"
    $OPENCLAW_CMD agent create "$agent" --workspace "$CORP_ROOT/workspaces/$agent" -y
done

# 3. Initialize Finance
echo "--- Initializing Ledger ---"
python3 "$CORP_ROOT/shared/manage_finance.py" audit

echo "✅ Deployment Complete."
echo "Workflow:"
echo "1. Scout:   $OPENCLAW_CMD agent run scout 'Find leads'"
echo "2. CMO:     $OPENCLAW_CMD agent run cmo 'Make plan'"
echo "3. Arch:    $OPENCLAW_CMD agent run arch 'Design spec'"
echo "4. CEO:     $OPENCLAW_CMD agent run ceo 'Decision'"
echo "5. Auditor: $OPENCLAW_CMD agent run accountant 'Audit'"
