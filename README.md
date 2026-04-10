# Profit-First SaaS Inc. 🚀
### A Self-Evolving, Profit-Driven Multi-Agent SaaS Incubator

Profit-First SaaS Inc. is an autonomous company structure built on top of [OpenClaw](https://github.com/anthropics/openclaw). It consists of 5 specialized agents working in a closed-loop economic system to identify, design, and manage micro-SaaS projects with a "zero-cost" mindset.

---

## 🏢 Company Structure

| Role | Responsibility | Key Skills |
| :--- | :--- | :--- |
| **CEO** | Final decision making, pivot/kill strategy, staff management. | `summarize`, `github` |
| **Scout** | Identifying real-world pain points with monetization potential. | `blogwatcher`, `xurl`, `summarize` |
| **CMO** | Market analysis, competitive audit, pricing strategy. | `github`, `gh-issues`, `blogwatcher` |
| **Architect** | Lean system design, shared-backend strategy, MVP spec. | `coding-agent`, `summarize`, `model-usage` |
| **Accountant** | Financial auditing, token cost tracking, bankruptcy enforcement. | `model-usage`, `healthcheck`, `session-logs` |

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

A single Telegram bot lets any team member (product manager, operator, non-technical CEO) control the entire agent team without touching the terminal.

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

> **One bot controls the whole team.** No need for a separate bot per agent.

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

### 1. Prerequisites
- [OpenClaw](https://github.com/anthropics/openclaw) core installed in the parent directory.
- Node.js & Python 3.
- Access to an LLM provider (Ollama for local, or Cloud API for server).

### 2. Setup
Clone this folder next to your `openclaw` directory and run:

**Linux/Mac:**
```bash
chmod +x deploy_corp.sh
./deploy_corp.sh
```

**Windows:**
```batch
deploy_corp.bat
```

---

## 🔄 The Pipeline (Daily Workflow)

1.  **Scout**: `node openclaw.mjs agent run scout "Scan for SaaS leads"`
2.  **CMO**: `node openclaw.mjs agent run cmo "Pick lead and design market plan"`
3.  **Arch**: `node openclaw.mjs agent run arch "Draft tech spec for the market plan"`
4.  **CEO**: `node openclaw.mjs agent run ceo "Decide to Greenlight or Veto"`
5.  **Audit**: `node openclaw.mjs agent run accountant "Perform daily audit"`

---

## 📂 Directory Map
*   `corp_config.json`: Master configuration for the local company (agents, Telegram, governance).
*   `shared/`: Financial engine, Ledger, RBAC config, Telegram bot, and communication templates.
*   `shared/telegram_bot.py`: Unified Telegram command centre.
*   `shared/rbac_config.json`: Role-based access control definitions.
*   `workspaces/`: Individual persistent memories and data for each agent.
*   `deploy_corp.sh/bat`: One-click setup for new environments.

---

🤖 *Generated & Optimized by Claude Code for Profit-First SaaS Inc.*
