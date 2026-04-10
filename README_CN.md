# Profit-First SaaS Inc. 🚀
[简体中文] | [English](README.md)
### 基于 OpenCLAW 原生架构的盈利驱动多智能体孵化器

Profit-Corp 提供了一套完整的 OpenCLAW 原生配置（无需外部桥接），包含五个智能体：CEO (Marcus)、Scout (Alex)、CMO (Jordan)、Architect (Sam) 和 Accountant (Taylor)。

---

## 项目包含内容
- `openclaw.json` 模板：多智能体配置，CEO 作为默认代理（移除旧版 `main`），包含 Telegram + WebChat 绑定，启用原生 Cron。
- 双重部署方案：`setup_corp.sh` 用于现有 OpenCLAW 环境，`docker-compose.yml` + `Dockerfile` 用于全栈容器化部署。
- 更新版一键脚本：`deploy_corp.sh` / `.bat` 使用 `openclaw agents add` 代替旧指令。
- 工作区剧本：位于 `workspaces/*/AGENTS.md`，共享账本逻辑位于 `shared/manage_finance.py`。
- 详细设计说明：[ARCHITECTURE_CN.md](ARCHITECTURE_CN.md)（包含路由、默认代理安全、WebChat 绑定等）。

---

## 通讯与路由 (原生)
- **默认代理:** CEO 被明确设为 `default: true`；没有 `main` 工作区，因此未匹配的输入始终流向 CEO。
- **绑定:** Telegram、WebChat 和 Webhook 均通过 `openclaw.json` 中的 `bindings[]` 绑定到 CEO。如需特定通道路由，可在此调整。
- **智能体间通讯:** 使用 OpenCLAW 工具（`sessions_spawn`、`sessions_send`、`sessions_history`）进行任务委派和跟进，无需手动复制粘贴。
- **WebChat:** 默认打开 CEO 控制台；如果在侧边栏绑定了其他 Agent，可以切换会话。
- **Cron:** 启用原生调度器（存储在 `~/.openclaw/cron/jobs.json`）。设置脚本会自动注册每日 08:00 的执行流水线。

---

## 部署选项
**模式 A: 现有 OpenCLAW 安装 (推荐用于本地)**
```bash
cp .env.example .env    # 填写 TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, OPENCLAW_HOOKS_TOKEN
./setup_corp.sh         # 写入 ~/.openclaw/openclaw.json，注册 Agents 和 Cron
```

**模式 B: 全栈 Docker 部署**
```bash
cp .env.example .env
docker-compose up -d    # 构建网关镜像，挂载工作区和账本卷
docker-compose logs -f openclaw
```

---

## 每日自动化与手动运行
- Cron 任务（由 `setup_corp.sh` 注册）：独立的 CEO 会话触发 Scout → CMO → Arch → CEO 决策 → Accountant 审计，如果设置了 Chat ID，会通过 Telegram 回复。
- 手动触发：
  - `openclaw cron run "Daily SaaS Incubator"` (命令行)
  - 或通过控制界面访问 `http://127.0.0.1:18789`

---

## 经济引擎 (账本)
`shared/manage_finance.py` 强制执行阶段划分和评分：
- **引导阶段 (Bootstrapping)** < 1,000 pts；**扩张阶段 (Scaling)** 1,000–10,000；**独角兽阶段 (Unicorn)** > 10,000；**生存模式 (Survival)** < 100（会有处罚）；0 点则宣告**破产**。
- 智能体必须通过 `python3 shared/manage_finance.py <action>` 记录操作；参考 `shared/TEMPLATES_CN.md` 编写输出。

---

## 目录结构
- `openclaw.json`: OpenCLAW 智能体、绑定和 Cron 配置。
- `setup_corp.sh`: 为现有 OpenCLAW 安装配置、智能体和 Cron。
- `docker-compose.yml` / `Dockerfile` / `docker-entrypoint.sh`: 容器化网关。
- `deploy_corp.sh` / `deploy_corp.bat`: 旧版快速启动（保留用于兼容性）。
- `shared/`: 账本、模板、企业文化记忆。
- `workspaces/<agent>/`: 智能体专用指令和记忆。

---

🤖 *由 Claude Code 为 Profit-First SaaS Inc. 生成并优化*
