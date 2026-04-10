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

## 🤖 Unified Telegram Interface

A **single Telegram bot** controls the entire company. All commands are routed through the **CEO** agent:

| Command | Effect |
| :--- | :--- |
| `/new_project [idea]` | Triggers a fresh Scout → CMO → Arch → CEO pipeline |
| `/revenue <pts> <source>` | Reports revenue into the treasury |
| `/balance` | Shows current treasury and agent balances |
| `/daily_run` | Manually triggers the full Daily Workflow right now |
| `/audit` | Asks the Accountant to run the financial audit |
| `/archive <project_name>` | Archives a completed/vetoed project |

Setup: obtain a bot token from [@BotFather](https://t.me/BotFather) and your numeric user ID from [@userinfobot](https://t.me/userinfobot). Both go into your `.env` file.

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
├── corp_config.json       # Agent skills, model interface, token quotas
├── docker-compose.yml     # Mode A: standalone deployment
├── install_extension.sh   # Mode B: plug into existing OpenClaw
├── setup_cron.sh          # Register daily workflow cron
├── .env.example           # Required environment variables
├── shared/
│   ├── manage_finance.py  # Economic engine (score, audit, quota, skills)
│   ├── context_manager.py # Shared context layer (pipeline state, archiving)
│   ├── global_state.json  # Live cross-agent context
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

