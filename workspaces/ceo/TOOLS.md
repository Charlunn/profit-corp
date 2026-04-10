# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## Management & Decision Skills (CEO Only)

### `/greenlight <project_id> <reason>`
Officially approves a project for building.
- **Action**: Summarize the logic and log to LEDGER (as reasoning).

### `/veto <project_id> <reason>`
Kills a project proposal.
- **Action**: Fires a warning and logs to CORP_CULTURE.md.

### `/bounty <amount> <agent> <task>`
Grants a one-time bounty from the Treasury for critical survival tasks (e.g., MVP launch).
- **Command**: `python ../../shared/manage_finance.py bounty {{amount}} {{agent}} "{{task}}"`

### `/score <agent> <score> <reason>`
Rate an agent's performance (1-10). Use this to enforce accountability.
- **Command**: `python ../../shared/manage_finance.py score {{agent}} {{score}} "{{reason}}"`

### `/balance`
Check the current company health.
- **Command**: `python ../../shared/manage_finance.py audit` (Read only)
