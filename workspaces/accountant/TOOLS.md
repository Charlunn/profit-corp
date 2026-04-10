# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## Financial Skills (Accountant Only)

### `/audit`
Performs the daily financial audit, deducting survival costs and checking for bankruptcy.
- **Command**: `python ../../shared/manage_finance.py audit`

### `/revenue <amount> <source_agent> <reasoning>`
Records incoming points/profit to the treasury and bonuses the relevant agent.
- **Command**: `python ../../shared/manage_finance.py revenue {{amount}} {{source_agent}} "{{reasoning}}"`

### `/token-log <agent> <input> <output>`
Logs token usage for an agent and applies the relevant penalty based on maturity level.
- **Command**: `python ../../shared/manage_finance.py tokens {{agent}} {{input}} {{output}}`

---

## Management Skills

### `/score <agent> <score> <reason>`
Rates a peer's performance (1-10). Impacts their survival points.
- **Command**: `python ../../shared/manage_finance.py score {{agent}} {{score}} "{{reason}}"`
