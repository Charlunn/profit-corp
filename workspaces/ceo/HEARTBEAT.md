# CEO Heartbeat Tasks

Every 4 hours, run this compact health check. Use an isolated session (configured in openclaw.json).

## Tasks

1. Read `shared/LEDGER.json`. Check:
   - Treasury balance vs. the `maturity_level` threshold (Bootstrapping < 1000, Scaling < 10000).
   - Any agent below 20 points (bankruptcy risk).
2. If Treasury < 150 → send a Telegram alert: "⚠️ **SURVIVAL MODE** — Treasury at <balance> pts. Immediate action required."
3. If any agent ≤ 0 → send alert: "🔴 **AGENT BANKRUPT**: <agent_name> is at <balance> pts. Review CORP_CULTURE.md and consider replacement."
4. If all agents > 80 pts and Treasury > 300 → no action needed (healthy).

