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
*   `corp_config.json`: Master configuration for the local company.
*   `shared/`: Financial engine, Ledger, and standardized communication templates.
*   `workspaces/`: Individual persistent memories and data for each agent.
*   `deploy_corp.sh/bat`: One-click setup for new environments.

---

🤖 *Generated & Optimized by Claude Code for Profit-First SaaS Inc.*
