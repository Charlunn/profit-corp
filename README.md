# Profit-First SaaS Inc. 🚀
### A Self-Evolving, Profit-Driven Multi-Agent SaaS Incubator

Profit-First SaaS Inc. is an autonomous company structure built on top of [OpenClaw](https://github.com/openclaw/openclaw). It consists of 5 specialized agents working in a closed-loop economic system to identify, design, and manage micro-SaaS projects with a "zero-cost" mindset.

---

## 🏢 Company Structure

| Role | Responsibility | Key Skills |
| :--- | :--- | :--- |
| **CEO** | Final decision making, pivot/kill strategy, Telegram entry-point. | `summarize`, `github` |
| **Scout** | Identifying real-world pain points with monetization potential. | `blogwatcher`, `xurl`, `summarize` |
| **CMO** | Market analysis, competitive audit, pricing strategy. | `github`, `gh-issues`, `blogwatcher` |
| **Architect** | Lean system design, shared-backend strategy, MVP spec, dynamic skill injection. | `coding-agent`, `summarize`, `model-usage` |
| **Accountant** | Financial auditing, token quota governance, model-upgrade interface. | `model-usage`, `healthcheck`, `session-logs` |

---

## 💰 Economic Engine (The Ledger)

The company operates under a strict points-based "Physics Engine" defined in `shared/manage_finance.py`:

*   **Bootstrapping Phase**: Treasury < 1,000 pts. Extreme token conservation. Only "Lean" projects allowed.
*   **Scaling Phase**: 1,000 - 10,000 pts. Balanced growth and efficiency.
*   **Unicorn Phase**: > 10,000 pts. High-performance reasoning enabled. Strategic dominance.
*   **Survival Mode**: Triggered if Treasury < 100. Maintenance costs are halved, but capability is limited.
*   **Bankruptcy**: If an agent hits 0 points, they are flagged for a "Reset Ritual" (Post-Mortem).

---

## 🏗️ Architectural Constraints

To maintain extreme lean operations, the **Architect** and **CEO** enforce:
1.  **Shared Backend**: All SaaS projects MUST share a single Supabase project (Isolated via Row Level Security & `saas_tag`).
2.  **Unified Domain**: All apps are served via Vercel rewrites: `profit-corp.com/apps/{{project_id}}`.
3.  **Zero-Cost First**: Priority is given to tools that fit within free tiers or student packs.

---

## 🤖 Telegram Bot — Unified Command Centre

A single Telegram bot (CEO entry-point) lets any team member control the agent team without touching the terminal. Commands are routed through the CEO but exposed with guided wizards and approval gates so non-technical users can operate safely.

### Features
| Feature | Description |
| :--- | :--- |
| **Bottom keyboard** | One-tap shortcuts: `/新项目`, `/汇报营收`, `/团队状态`, `/日报`, `/归档列表`, `/帮助` |
| **Suggested commands** | Telegram's built-in "/" menu lists all available commands |
| **`/新项目` wizard** | Step-by-step guided onboarding — no complex parameters needed |
| **`/汇报营收` wizard** | Two-step revenue reporting with auto ledger update |
| **Confirmation pop-ups** | Inline ✅/❌ buttons before any sensitive action executes |
| **Approval flow** | Delete / archive / reset requests are sent to super_admin for approval |
| **RBAC** | Four roles: `超级管理员`, `管理员`, `运营`, `只读` (see `shared/rbac_config.json`) |
| **Daily tips** | Common command reference appended after every major response |

### Quick Start

**1. Get your credentials**
*   Bot Token: message [@BotFather](https://t.me/BotFather) → `/newbot`
*   Your Telegram User ID: message [@userinfobot](https://t.me/userinfobot)

**2. Install dependency**
```bash
pip3 install "python-telegram-bot>=20.0"
```

**3. Run the bot**
```bash
export TELEGRAM_BOT_TOKEN=<your_token>
export TELEGRAM_ALLOWED_USERS=<your_telegram_user_id>   # first ID = super_admin
python3 shared/telegram_bot.py
```

> Using Docker/OpenClaw? Fill the Telegram fields in `.env` and follow the deployment section below.

### Available Commands

| Command | Permission | Description |
| :--- | :--- | :--- |
| `/start` | any | Show welcome screen & keyboard |
| `/xin_xiang_mu` | operator+ | Interactive new-project wizard |
| `/hui_bao_ying_shou` | operator+ | Revenue reporting wizard |
| `/tuan_dui_zhuang_tai` | readonly+ | Team & treasury status |
| `/ri_bao` | admin+ | Trigger daily financial audit |
| `/ping_fen <agent> <1-10> <reason>` | admin+ | Score an agent |
| `/fa_fang_jiang_jin <amt> <agent> <task>` | admin+ | Grant a bounty from treasury |
| `/gui_dang_lie_biao` | readonly+ | List archived projects |
| `/gui_dang_xiang_mu <name>` | admin+ | Archive a project (needs approval) |
| `/shan_chu_xiang_mu <name>` | admin+ | Delete a project (needs super_admin approval) |
| `/chong_zhi_agent <agent>` | admin+ | Reset an agent (needs super_admin approval) |
| `/help` | any | Full command reference |

---

## 🔒 Business Governance (RBAC)

Sensitive operations are protected by a two-layer system:

1. **Role check** — the user's role must hold the required permission.
2. **Confirmation pop-up** — an inline ✅/❌ keyboard appears before execution.
3. **Approval flow** (for destructive ops) — a request card is sent to all `super_admin` users with ✅ 批准 / ❌ 拒绝 buttons.

### Role Configuration (`shared/rbac_config.json`)

```jsonc
{
  "roles": {
    "super_admin": { "permissions": ["all"],  "users": [123456789] },
    "admin":       { "permissions": ["new_project", "report_revenue", "daily_audit", ...], "users": [] },
    "operator":    { "permissions": ["new_project", "report_revenue", "view_status", ...], "users": [] },
    "readonly":    { "permissions": ["view_status", "view_archive"], "users": [] }
  },
  "require_approval": ["delete_project", "archive_project", "reset_agent"]
}
```

> Add Telegram user IDs to each role's `"users"` array.  
> If the array is empty, the first ID in `TELEGRAM_ALLOWED_USERS` is promoted to `super_admin` automatically.

---

## 🚀 Deployment

### Prerequisites
*   [OpenClaw](https://github.com/openclaw/openclaw) (`npm install -g openclaw@latest`)
*   Node.js 22.16+ and Python 3
*   Docker + Docker Compose v2 (for Mode A)
*   OpenRouter API key (free tier models available)
*   Telegram bot token + owner user ID

---

### Mode A — Standalone Docker (full stack)

Use this if you **do not** have OpenClaw deployed yet.

```bash
# 1. Copy and fill in your credentials
cp .env.example .env

# 2. Start the gateway (downloads openclaw:latest automatically)
docker compose up -d

# 3. Add the Telegram channel
docker compose run --rm openclaw-cli channels add \
  --channel telegram --token "$TELEGRAM_BOT_TOKEN"

# 4. Register the daily 08:00 cron job
docker compose run --rm openclaw-cli bash -c \
  "TELEGRAM_OWNER_ID=$TELEGRAM_OWNER_ID CORP_TZ=$CORP_TZ bash /home/node/.openclaw/workspace/profit-corp/setup_cron.sh"

# 5. Open the Control UI
docker compose run --rm openclaw-cli dashboard --no-open
# → http://127.0.0.1:18789 (paste OPENCLAW_GATEWAY_TOKEN from .env)
```

---

### Mode B — Plugin/Extension (existing OpenClaw install)

Use this if you **already have OpenClaw** running on a VPS or locally.

```bash
# 1. Copy openclaw.json to your OpenClaw config directory
#    (edit workspace paths inside it to match your clone location first)
cp openclaw.json ~/.openclaw/openclaw.json

# 2. Fill in .env, then run the install script
cp .env.example .env
# edit .env …

# 3. Run the extension installer
chmod +x install_extension.sh
TELEGRAM_OWNER_ID=<your_id> CORP_TZ=Asia/Shanghai ./install_extension.sh

# 4. Restart the gateway so agent changes take effect
openclaw gateway restart
```

---

## 🔄 The Pipeline (Daily Workflow)

The workflow runs automatically at **08:00** via OpenClaw's native cron scheduler.
Each step updates `shared/global_state.json` so all agents share a live context.

1.  **Scout**: Find 3+ SaaS leads → write `shared/PAIN_POINTS.md`
2.  **CMO**: Pick best lead → write `shared/MARKET_PLAN.md`
3.  **Arch**: Design MVP tech spec → write `shared/TECH_SPEC.md`
4.  **CEO**: Greenlight or veto → write `shared/CEO_DECISION.md`
5.  **Accountant**: Daily audit + token quota enforcement

After the pipeline, the CEO sends a summary to your Telegram.

---

## 🧠 Memory & Archiving

*   **Global State** (`shared/global_state.json`): live pipeline stage and cross-agent shared context.
*   **Workspace files** (`workspaces/<agent>/`): each agent's persistent memory (AGENTS.md, SOUL.md, etc.) stored in OpenClaw's workspace format and injected at session start.
*   **Archives** (`archives/<project_name>/`): completed/vetoed project artefacts plus a global-state snapshot. Trigger via `/archive <name>` or the weekly Sunday cron.

```bash
# View project history
python3 shared/context_manager.py history

# Read/write global state manually
python3 shared/context_manager.py read active_project
python3 shared/context_manager.py write active_project '"my-saas-app"'
```

---

## ⚙️ Dynamic Skill Injection

The **Architect** can inject new skills into any agent at runtime:

```bash
# Inject a skill (persisted to corp_config.json)
python3 shared/manage_finance.py inject_skill scout browser-tool

# Remove a skill
python3 shared/manage_finance.py remove_skill scout browser-tool
```

Agents pick up the new skills on their next session restart.

---

## 📂 Directory Map

```
profit-corp/
├── openclaw.json          # OpenClaw gateway config (copy to ~/.openclaw/)
├── corp_config.json       # Agent skills, model interface, token quotas, Telegram config
├── docker-compose.yml     # Mode A: standalone deployment
├── install_extension.sh   # Mode B: plug into existing OpenClaw
├── setup_cron.sh          # Register daily workflow cron
├── .env.example           # Required environment variables
├── shared/
│   ├── manage_finance.py  # Economic engine (score, audit, quota, skills)
│   ├── context_manager.py # Shared context layer (pipeline state, archiving)
│   ├── global_state.json  # Live cross-agent context
│   ├── telegram_bot.py    # Unified Telegram command centre
│   ├── rbac_config.json   # Role-based access control definitions
│   ├── LEDGER.json        # Treasury and agent points
│   ├── CORP_CULTURE.md    # Collective lessons learned
│   └── TEMPLATES.md       # Output templates for each agent
├── workspaces/            # Per-agent OpenClaw workspace directories
│   ├── scout/
│   ├── cmo/
│   ├── arch/
│   ├── ceo/               # ← Telegram entry-point
│   └── accountant/
└── archives/              # Auto-archived project artefacts
```

---

🤖 *Built on OpenClaw — the personal AI assistant that actually does things.*
