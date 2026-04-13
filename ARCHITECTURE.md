# Profit-Corp Architecture: OpenCLAW Native Integration Guide
[English] | [简体中文](ARCHITECTURE_CN.md)

> **Purpose**: This document answers the user's direct questions about OpenCLAW's
> communication mechanisms, the default agent, and webchat routing. All analysis
> is based on the [OpenCLAW source and docs](https://github.com/openclaw/openclaw).

---

## 1. OpenCLAW Native Communication Mechanisms

OpenCLAW provides several **native** inter-agent and channel communication layers.
Profit-corp is built to use **only** these — no redundant external message brokers.

### 1.1 Channel Routing (Inbound)

All external input (Telegram, WebChat, webhooks) is routed via the **`bindings[]`**
array in `openclaw.json`. This is deterministic and most-specific-first:

```
peer match → parentPeer → guildId+roles → guildId → teamId → accountId → channel → default agent
```

Profit-corp binding strategy:
- **Telegram** → CEO (dispatcher). CEO can spawn sub-agents as needed.
- **WebChat** (Control UI) → CEO. One entry point for the web panel.
- **Webhook** → CEO. External triggers land at CEO.

### 1.2 Agent-to-Agent Messaging (Native)

OpenCLAW provides two native tools for agent-to-agent communication:

| Tool | Purpose |
|---|---|
| `sessions_spawn` | Spawn a background run of another agent with a message |
| `sessions_send` | Send a follow-up message into an existing agent session |
| `sessions_history` | Retrieve bounded, sanitized session transcript for recall |
| `sessions_list` | List active sessions across agents |

These tools are enabled in `openclaw.json` via `tools.agentToAgent.enabled: true` and
`tools.agentToAgent.allow: ["ceo", "scout", "cmo", "arch", "accountant"]`.

**How the daily pipeline works (native)**:
1. Cron fires at 08:00 → isolated CEO session
2. CEO uses `sessions_spawn({ agentId: "scout", message: "..." })` → Scout runs
3. Scout writes `shared/PAIN_POINTS.md`, completes
4. CEO spawns CMO, passes Scout output via session message
5. CMO → Arch → CEO decision loop, all via `sessions_spawn`
6. CEO delivers final report via Telegram (`announce` delivery mode on the cron job)

> **No external message bus needed.** OpenCLAW's session model IS the message bus.

### 1.3 Scheduled Tasks (Native Cron)

OpenCLAW's built-in `cron` scheduler replaces external `cron`/`systemd` timers:

```bash
# Daily 08:00 pipeline (set up once during deployment)
openclaw cron add \
  --name "Daily SaaS Incubator" \
  --cron "0 8 * * *" \
  --tz "YOUR_TIMEZONE" \
  --agent ceo \
  --session isolated \
  --message "Good morning. Start the daily pipeline: 1) Ask Scout to scan for leads, 2) Ask CMO to pick the best lead, 3) Ask Arch to draft a tech spec, 4) Make your GO/NO-GO decision, 5) Ask Accountant to run the audit. Report the final outcome to Telegram." \
  --announce \
  --channel telegram \
  --to "YOUR_TELEGRAM_CHAT_ID"
```

Jobs persist at `~/.openclaw/cron/jobs.json` — they survive gateway restarts.

### 1.4 Webhooks (Native HTTP Hooks)

OpenCLAW exposes `POST /hooks/agent` for external triggers:

```bash
# Trigger a new project from any external system
curl -X POST http://127.0.0.1:18789/hooks/agent \
  -H "Authorization: Bearer $OPENCLAW_HOOKS_TOKEN" \
  -d '{"agentId":"ceo","message":"New project idea: [your idea here]"}'
```

### 1.5 Audit Log (Financial Ledger)

All financial activities (revenue, bounties, operational costs, token penalties) are appended to `shared/AUDIT_LOG.csv`. This provides the company with a transparent and traceable financial history for long-term ROI analysis of each agent.

---

## 2. Default Agent: Safety Analysis

### 2.1 What is the "default agent"?

In OpenCLAW's multi-agent mode, the **default agent** is the fallback for messages
that don't match any binding. It is **not** a special system process — it is simply
whichever agent in `agents.list[]` has `default: true` (or the first entry if none
is marked).

In single-agent mode, the default agent is `main`. In profit-corp's config, there
is **no `main` agent**. Instead, **CEO is the default** (`"default": true` in the
CEO entry of `agents.list`).

### 2.2 Can the default agent be safely removed?

**Yes — with caveats.**

The `main` agent slot is only a concern if:
1. You have no `agents.list` and rely on the fallback `main` workspace.
2. You have leftover sessions in `~/.openclaw/agents/main/sessions/` that you want
   to keep.

For profit-corp:
- We define a full `agents.list` with 5 corp agents.
- CEO is marked `default: true`.
- There is no `main` workspace — OpenCLAW will never route to one.
- The Control UI (WebChat) tab will show the CEO agent by default.

**Result**: The `main` default agent is effectively gone. No residual routing leaks.

### 2.3 Will keeping a default affect org independence?

If the old `main` agent workspace still exists at `~/.openclaw/workspace` and no
explicit `default` agent is set, OpenCLAW falls back to it. This would create a
"ghost" agent that receives unmatched messages — exactly the "game corrupting
the team structure" scenario.

**Fix**: the deployment scripts explicitly:
1. Remove / skip the `main` workspace initialization.
2. Set `ceo` as `default: true` in `agents.list`.
3. Add explicit bindings for every channel.

### 2.4 WebChat binding to specific agents

The Control UI WebChat tab uses the **same binding + routing system** as other
channels. You can bind it explicitly:

```json5
bindings: [
  { agentId: "ceo",       match: { channel: "webchat" } },        // default
  { agentId: "scout",     match: { channel: "webchat", peer: { id: "scout-tab" } } },
  { agentId: "accountant",match: { channel: "webchat", peer: { id: "audit-tab" } } },
]
```

For profit-corp, **all WebChat → CEO**. You can address specific agents directly
in the OpenCLAW Control UI by switching the active agent session in the sidebar
(each agent has its own chat session in the UI).

---

## 3. Telegram Integration Architecture

### 3.1 One Bot Token, One Team

Profit-corp uses **a single Telegram bot token** routed to CEO. This is by design:

- You talk to CEO as the company director.
- CEO dispatches work to Scout, CMO, Arch, Accountant using `sessions_spawn`.
- Results are aggregated and delivered back via the same Telegram session.

### 3.2 Bot Commands

Commands registered in `openclaw.json` under `channels.telegram.customCommands`
appear in Telegram's "/" menu as **clickable buttons**. No manual typing needed:

| Command | Target |
|---|---|
| `/help` | CEO replies with formatted command list |
| `/new_project` | CEO runs auto discovery (48h) → quantitative ranking Top3 → user select → pipeline continues |
| `/status` | CEO reads LEDGER.json |
| `/daily` | CEO triggers full pipeline |
| `/revenue <amt> <src> <note>` | Accountant records revenue (RBAC gate if ≥ 1000) |
| `/bounty <amount> <agent> <task>` | CEO grants bounty (RBAC gate if ≥ 500) |
| `/greenlight <id> <reason>` | CEO approves project |
| `/veto <id> <reason>` | CEO kills project |
| `/audit` | Accountant runs daily audit |
| `/archive <project>` | CEO archives project (RBAC gate — always requires `/confirm`) |
| `/confirm` | Confirms the last pending sensitive operation |
| `/cancel` | Cancels the last pending sensitive operation |

### 3.3 `/new_project` Auto Flow (Default)

For shareholder efficiency, `/new_project` now runs an execution-first flow by default:

```
User: /new_project
CEO:  🚀 已启动自动流程：我会先抓取近48小时机会并量化评分，随后给你Top3供选择。
      [sessions_spawn Scout + CMO]
CEO:  这是Top3候选（含总分与分项）。请回复 1/2/3 或 idea_id。
User: 2
CEO:  已确认。现在推进 MARKET_PLAN -> TECH_SPEC -> GO/NO-GO。
      [CMO 深化 + Arch 规格 + CEO 决策]
```

默认不再逐条追问 kickoff 基础信息（除非股东明确要求“自定义模式”）。

### 3.4 Failure & Data-Limit Fallbacks

When fresh external evidence is insufficient:
- First keep strict 48h window;
- If qualified candidates < 3, expand to 7 days and label affected ideas with low confidence;
- If external search is unavailable, output provisional ideas marked `NEEDS_VERIFICATION` and continue after explicit shareholder selection.

Agents must not fabricate certainty: all low-confidence assumptions must be explicitly labeled in outputs.

### 3.5 RBAC Confirmation Gates

Sensitive operations require the user to type `/confirm` before execution:

```
User: /revenue 1500 stripe "Annual subscription"
CEO:  💰 You're about to record 1500 pts from stripe.
      Reply /confirm to proceed or /cancel to abort.
User: /confirm
CEO:  ✅ Revenue recorded! Treasury: 2,000 pts. Phase: Scaling!
```

The same two-step gate applies to:
- `/bounty` when amount ≥ 500
- All `/archive` requests
- Any `fire_agent` or `governance` change requests

Any reply other than `/confirm` cancels the pending action. `/cancel` clears the queue explicitly.
The `rbac.sensitiveOps` list in `openclaw.json` documents the full policy.

### 3.6 Feedback Loop

```
You → /revenue 500 product_hunt "App featured"
         ↓
      Telegram → OpenCLAW (CEO session)
         ↓
      CEO → sessions_spawn(accountant, "Record revenue: 500 pts...")
         ↓
      Accountant → python shared/manage_finance.py revenue 500 ...
         ↓
      Accountant result → CEO
         ↓
      CEO → Telegram reply: "💰 Revenue recorded. Treasury: 1,000 pts. Phase: Scaling!"
```

---

## 4. Deployment Architecture

### Mode A: Existing OpenCLAW Installation

Use `setup_corp.sh`:
```bash
cd /path/to/profit-corp
./setup_corp.sh
```

This script:
1. Detects OpenCLAW installation.
2. Interactively handles existing `openclaw.json` (`overwrite` / `merge-update` / `skip`; default `merge-update`).
3. **Removes any legacy `main` default agent** (`openclaw agents remove main --force`).
4. Runs `openclaw agents add` for each corp agent.
5. Registers the daily cron job.
6. Verifies with `openclaw agents list --bindings`.

### Mode B: Full Docker Stack

Use `docker-compose up -d`:
```bash
cp .env.example .env       # fill in tokens
docker-compose up -d
```

This spins up:
- OpenCLAW gateway (with profit-corp config auto-applied)
- Persistent volumes for workspaces, sessions, cron, and the ledger
- **Entrypoint automatically removes any leftover `main` agent on every start**

### File Locations

| Item | Location |
|---|---|
| OpenCLAW config | `~/.openclaw/openclaw.json` |
| Agent sessions | `~/.openclaw/agents/<id>/sessions/` |
| Cron jobs | `~/.openclaw/cron/jobs.json` |
| Corp workspaces | `PROFIT_CORP_ROOT/workspaces/<agent>/` |
| Shared ledger | `PROFIT_CORP_ROOT/shared/LEDGER.json` |
| Knowledge base | `PROFIT_CORP_ROOT/shared/KNOWLEDGE_BASE.md` |
| Project archives | `PROFIT_CORP_ROOT/archives/<project>/` |

---

## 5. Knowledge Flow & Cross-Project Memory

### 5.1 Knowledge Base

`shared/KNOWLEDGE_BASE.md` is the company's long-term memory. It stores structured
"knowledge cards" — one card per major decision, lesson, or milestone.

**Format**:
```markdown
## Card: <Project/Event Name> — <YYYY-MM-DD>
- **Type**: decision | failure | pattern | milestone
- **Outcome**: GO/NO-GO/revenue/veto/archive
- **Lesson**: one-line key insight
- **Tags**: #revenue #bootstrapping #competition
```

**Who writes**: CEO after GO/NO-GO decisions, Accountant after audits.
**Who reads**: All agents at session start (consult before major decisions).

### 5.2 Context Injection Flow

```
Session Start
    ↓
CEO reads shared/KNOWLEDGE_BASE.md (company memory)
    ↓
CEO reads shared/CORP_CULTURE.md (team rules & lessons)
    ↓
CEO reads shared/LEDGER.json (current treasury/scores)
    ↓
Decision / dispatch
    ↓
CEO writes new knowledge card to KNOWLEDGE_BASE.md (if noteworthy)
```

The same pattern applies to sub-agents: Scout reads KNOWLEDGE_BASE.md to avoid
repeating failed lead categories; CMO reads it to avoid previously vetoed markets.

### 5.3 Session History Recall

For in-session cross-agent recall, use OpenCLAW's `sessions_history` tool:

```
sessions_history({ agentId: "scout", limit: 20 })
// Returns the last 20 messages from Scout's most recent session
```

This avoids re-running work that was already done in the same pipeline cycle.

---

## 6. RBAC & Permission System

### 6.1 Policy

Profit-corp implements a two-level permission model:

| Level | Description |
|---|---|
| `operator` | Can run all read commands + start new projects + trigger pipeline |
| `owner` | Can additionally execute financial changes, archive, governance |

All users in `channels.telegram.allowFrom` are trusted as `owner` by default (the
allowlist is your personal ID). If you add team members, add a lower-trust tier by
restricting which commands they can trigger via separate agent bindings.

### 6.2 Confirmation Gates

For sensitive operations CEO will **pause and ask for `/confirm`** before executing:

| Operation | Trigger | Reason |
|---|---|---|
| `/revenue <amount ≥ 1000>` | amount ≥ 1000 | Large financial change |
| `/bounty <amount ≥ 500>` | amount ≥ 500 | Large bounty grant |
| `/archive <project>` | always | Irreversible action |
| `fire_agent` | always | Org structure change |
| `governance` | always | Company-wide policy change |

The full policy is declared in `openclaw.json` under the `rbac.sensitiveOps` key.

---

## 7. Answers to Open Questions

### Q: Can the default agent be safely removed?
**Yes.** Set `default: true` on the CEO agent in `agents.list`. No `main` workspace
needed. All unmatched input lands at CEO. Both `setup_corp.sh` and
`docker-entrypoint.sh` explicitly remove any leftover `main` workspace.

### Q: Will keeping a default agent affect multi-agent independence?
**No**, as long as CEO is explicitly set as the default and all channels have explicit
bindings. The old `main` fallback is simply replaced by CEO.

### Q: Can WebChat be bound to a specific agent?
**Yes.** Use `bindings: [{ agentId: "ceo", match: { channel: "webchat" } }]`.
The Control UI also lets you switch active agent sessions via its sidebar.

### Q: Can all Telegram I/O go through OpenCLAW natively?
**Yes.** `channels.telegram` config + `bindings` handle routing. No external
Telegram bridge code needed. The `customCommands` key registers clickable
menu buttons in the Telegram bot.

### Q: Are there any redundant communication layers?
**No, after this integration.** The setup uses:
- `openclaw agents add` for registration
- `openclaw cron add` for scheduling
- `channels.telegram` for channel integration
- `sessions_spawn` / `sessions_send` for agent-to-agent calls
- `bindings[]` for channel routing

All layers are native to OpenCLAW.
