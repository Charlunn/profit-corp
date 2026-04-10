# Profit-Corp 架构：OpenCLAW 原生集成指南
[简体中文] | [English](ARCHITECTURE.md)

> **目的**：本文档旨在回答关于 OpenCLAW 通讯机制、默认代理及 WebChat 路由的直接问题。所有分析均基于 [OpenCLAW 源码及文档](https://github.com/openclaw/openclaw)。

---

## 1. OpenCLAW 原生通讯机制

OpenCLAW 提供了多种**原生**的智能体间和通道通讯层。
Profit-corp 旨在**仅**使用这些层，无需冗余的外部消息代理。

### 1.1 通道路由（入站）

所有外部输入（Telegram, WebChat, webhooks）均通过 `openclaw.json` 中的 **`bindings[]`** 数组路由。这是确定性的，且遵循最具体匹配优先原则：

```
peer 匹配 → parentPeer → guildId+roles → guildId → teamId → accountId → channel → 默认代理
```

Profit-corp 绑定策略：
- **Telegram** → CEO（调度员）。CEO 可根据需要派生子智能体。
- **WebChat**（控制界面） → CEO。Web 面板的统一入口。
- **Webhook** → CEO。外部触发器均落地于 CEO。

### 1.2 智能体间消息传递（原生）

OpenCLAW 为智能体间通讯提供了两个原生工具：

| 工具 | 用途 |
|---|---|
| `sessions_spawn` | 携带消息启动另一个智能体的后台运行 |
| `sessions_send` | 向现有的智能体会话发送后续消息 |
| `sessions_history` | 检索受限的、经过清理的会话记录用于召回 |
| `sessions_list` | 列出跨智能体的活动会话 |

这些工具通过 `openclaw.json` 中的 `tools.agentToAgent.enabled: true` 和
`tools.agentToAgent.allow: ["ceo", "scout", "cmo", "arch", "accountant"]` 启用。

**每日流水线如何工作（原生）**：
1. Cron 在 08:00 触发 → 隔离的 CEO 会话
2. CEO 使用 `sessions_spawn({ agentId: "scout", message: "..." })` → Scout 运行
3. Scout 写入 `shared/PAIN_POINTS.md`，完成运行
4. CEO 派生 CMO，通过会话消息传递 Scout 的输出
5. CMO → Arch → CEO 决策循环，全部通过 `sessions_spawn` 实现
6. CEO 通过 Telegram 交付最终报告（Cron 任务上的 `announce` 交付模式）

> **无需外部消息总线。** OpenCLAW 的会话模型本身就是消息总线。

### 1.3 计划任务（原生 Cron）

OpenCLAW 内置的 `cron` 调度器取代了外部 `cron`/`systemd` 定时器：

```bash
# 每日 08:00 流水线（在部署期间设置一次）
openclaw cron add \
  --name "Daily SaaS Incubator" \
  --cron "0 8 * * *" \
  --tz "YOUR_TIMEZONE" \
  --agent ceo \
  --session isolated \
  --message "早上好。启动每日流水线：1) 让 Scout 扫描潜在机会，2) 让 CMO 挑选最佳机会，3) 让 Arch 起草技术规范，4) 做出 GO/NO-GO 决策，5) 让 Accountant 运行审计。将最终结果报告至 Telegram。" \
  --announce \
  --channel telegram \
  --to "YOUR_TELEGRAM_CHAT_ID"
```

任务持久化在 `~/.openclaw/cron/jobs.json` —— 它们在网关重启后依然存在。

### 1.4 Webhooks（原生 HTTP 钩子）

OpenCLAW 暴露了 `POST /hooks/agent` 用于外部触发：

```bash
# 从任何外部系统触发新项目
curl -X POST http://127.0.0.1:18789/hooks/agent \
  --header "Authorization: Bearer $OPENCLAW_HOOKS_TOKEN" \
  --data '{"agentId":"ceo","message":"新项目点子：[在此处输入你的点子]"}'
```

### 1.5 审计日志 (财务流水)

所有财务活动（收入、奖金、运营成本、Token 惩罚）都会被追加记录到 `shared/AUDIT_LOG.csv` 中。这为公司提供了透明且可追溯的财务流水，用于长期分析各智能体的 ROI。

---

## 2. 默认智能体：安全分析

### 2.1 什么是“默认智能体”？

在 OpenCLAW 的多智能体模式下，**默认智能体**是所有不匹配任何绑定的消息的回退。它**不是**一个特殊的系统进程 —— 它只是 `agents.list[]` 中标记为 `default: true` 的智能体（如果未标记，则为第一个条目）。

在单智能体模式下，默认智能体是 `main`。在 profit-corp 的配置中，**没有 `main` 智能体**。相反，**CEO 是默认值**（CEO 条目中的 `"default": true`）。

### 2.2 默认智能体可以安全移除吗？

**可以 —— 但有注意事项。**

`main` 代理槽位仅在以下情况是一个问题：
1. 你没有 `agents.list` 并依赖回退的 `main` 工作区。
2. 你在 `~/.openclaw/agents/main/sessions/` 中有想要保留的剩余会话。

对于 profit-corp：
- 我们定义了一个包含 5 个企业智能体的完整 `agents.list`。
- CEO 被标记为 `default: true`。
- 没有 `main` 工作区 —— OpenCLAW 永远不会路由到它。
- 控制界面（WebChat）标签页默认显示 CEO 智能体。

**结果**：旧的 `main` 默认代理已有效移除。没有残留的路由泄漏。

### 2.3 保留默认值会影响组织的独立性吗？

如果旧的 `main` 智能体工作区仍存在于 `~/.openclaw/workspace` 且未设置显式的 `default` 智能体，OpenCLAW 会回退到它。这会创建一个“幽灵”代理来接收未匹配的消息 —— 正是“游戏破坏团队结构”的情况。

**修复方案**：部署脚本明确执行以下操作：
1. 移除/跳过 `main` 工作区的初始化。
2. 在 `agents.list` 中将 `ceo` 设置为 `default: true`。
3. 为每个通道添加显式绑定。

---

## 3. Telegram 集成架构

### 3.1 一个 Bot Token，一个团队

Profit-corp 使用**单个 Telegram bot token** 路由至 CEO。这是设计使然：

- 你作为公司董事与 CEO 对话。
- CEO 使用 `sessions_spawn` 将工作派发给 Scout、CMO、Arch、Accountant。
- 结果汇总后通过同一个 Telegram 会话交付。

### 3.2 Bot 指令

在 `openclaw.json` 的 `channels.telegram.customCommands` 下注册的指令将作为**可点击按钮**出现在 Telegram 的 "/" 菜单中。无需手动输入：

| 指令 | 目标 |
|---|---|
| `/help` | CEO 回复格式化的指令列表 |
| `/new_project` | CEO 运行交互式引导问卷 → Scout 链 |
| `/status` | CEO 读取 LEDGER.json |
| `/daily` | CEO 触发完整的流水线 |
| `/revenue <amt> <src> <note>` | Accountant 记录收入（≥ 1000 时有 RBAC 门禁） |
| `/bounty <amount> <agent> <task>` | CEO 授予奖金（≥ 500 时有 RBAC 门禁） |
| `/greenlight <id> <reason>` | CEO 批准项目 |
| `/veto <id> <reason>` | CEO 否决项目 |
| `/audit` | Accountant 运行每日审计 |
| `/archive <project>` | CEO 归档项目（RBAC 门禁 —— 始终需要 `/confirm`） |
| `/confirm` | 确认上一个待处理的敏感操作 |
| `/cancel` | 取消上一个待处理的敏感操作 |

---

## 4. RBAC 与权限系统

Profit-corp 实现了两级权限模型：

| 级别 | 描述 |
|---|---|
| `operator` | 可以运行所有读取指令 + 启动新项目 + 触发流水线 |
| `owner` | 此外还可以执行财务修改、归档、治理操作 |

`channels.telegram.allowFrom` 列表中的所有用户默认被信任为 `owner`（允许列表通常包含你的个人 ID）。

### 确认门禁

对于敏感操作，CEO 会**暂停并请求 `/confirm`** 后再执行。详情请参阅 `openclaw.json` 中的 `rbac.sensitiveOps`。
