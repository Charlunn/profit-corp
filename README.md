# Profit-First SaaS Inc. 🚀
### OpenCLAW-Native, Profit-Driven Multi-Agent Incubator

Profit-Corp ships a complete, native OpenCLAW setup (no external bridges) with five agents: CEO, Scout, CMO, Architect, and Accountant.

---

## What This Repo Includes
- `openclaw.json` template: multi-agent config, CEO as default (no legacy `main`), Telegram + WebChat bindings, native cron enabled.
- Dual deployment: `setup_corp.sh` for existing OpenCLAW installs, `docker-compose.yml` + `Dockerfile` for full-stack containers.
- Updated one-click scripts: `deploy_corp.sh` / `.bat` use `openclaw agents add` instead of legacy commands.
- Workspace playbooks in `workspaces/*/AGENTS.md` and shared ledger logic in `shared/manage_finance.py`.
- Detailed design notes in `ARCHITECTURE.md` (routing, default-agent safety, webchat binding).

---

## Communication & Routing (Native)
- **Default agent:** CEO is explicitly `default: true`; there is no `main` workspace, so unmatched input always lands on CEO.
- **Bindings:** Telegram, WebChat, and webhooks all bind to CEO via `bindings[]` in `openclaw.json`. Adjust there if you want channel-specific routing.
- **Agent-to-agent:** Use OpenCLAW tools (`sessions_spawn`, `sessions_send`, `sessions_history`) for delegation and follow-ups—no copy/paste relays.
- **WebChat:** Control UI opens on CEO by default; you can switch agent sessions in the sidebar if you bind others.
- **Cron:** Native scheduler is enabled (stored in `~/.openclaw/cron/jobs.json`). Setup scripts register the daily pipeline at 08:00 in your timezone.

---

## Deployment Options
**Mode A: Existing OpenCLAW installation (recommended for local)**
```bash
cp .env.example .env    # fill TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, OPENCLAW_HOOKS_TOKEN
./setup_corp.sh         # writes ~/.openclaw/openclaw.json, registers agents + cron
```

**Mode B: Full Docker stack**
```bash
cp .env.example .env
docker-compose up -d    # builds gateway image, mounts workspaces + ledger volumes
docker-compose logs -f openclaw
```

---

## Daily Automation & Manual Runs
- Cron job (registered by `setup_corp.sh`): isolated CEO session triggers Scout → CMO → Arch → CEO decision → Accountant audit, then replies via Telegram if a chat ID is set.
- Trigger manually:
  - `openclaw cron run "Daily SaaS Incubator"` (CLI)
  - or use the Control UI at `http://127.0.0.1:18789`

---

## Economic Engine (Ledger)
`shared/manage_finance.py` enforces phases and scores:
- Bootstrapping < 1,000 pts; Scaling 1,000–10,000; Unicorn > 10,000; Survival < 100 with penalties; Bankruptcy at 0.
- Agents must record actions via `python3 shared/manage_finance.py <action>`; see `shared/TEMPLATES.md` for writing outputs.

---

## Directory Map
- `openclaw.json`: OpenCLAW agent, binding, and cron configuration.
- `setup_corp.sh`: Install config + agents + cron for existing OpenCLAW.
- `docker-compose.yml` / `Dockerfile` / `docker-entrypoint.sh`: Containerized gateway.
- `deploy_corp.sh` / `deploy_corp.bat`: Legacy quickstart (kept for compatibility).
- `shared/`: Ledger, templates, cultural memory.
- `workspaces/<agent>/`: Agent-specific instructions and memory.

---

🤖 *Generated & Optimized by Claude Code for Profit-First SaaS Inc.*
