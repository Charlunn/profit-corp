"""Profit-Corp Telegram Bot
=========================
A unified Telegram command center for the Profit-First SaaS Inc. multi-agent system.

Features:
  - Context-aware natural language menus (inline keyboards + bottom custom keyboard)
  - Interactive /新项目 wizard: guided step-by-step project onboarding
  - Interactive /汇报营收 wizard: guided revenue reporting
  - RBAC: Role-based access control (super_admin / admin / operator / readonly)
  - Multi-level approval flow for sensitive ops (delete, archive, reset_agent)
  - Confirmation pop-up for every critical parameter change
  - Daily tips and common commands pushed after every action

Setup:
  pip install python-telegram-bot
  export TELEGRAM_BOT_TOKEN=<your_token>
  export TELEGRAM_ALLOWED_USERS=123456789          # comma-separated Telegram user IDs
  python shared/telegram_bot.py

The first ID in TELEGRAM_ALLOWED_USERS is treated as super_admin if no roles are
explicitly configured in shared/rbac_config.json.
"""

import json
import logging
import os
import subprocess
from datetime import datetime
from pathlib import Path

from telegram import (
    BotCommand,
    InlineKeyboardButton,
    InlineKeyboardMarkup,
    KeyboardButton,
    ReplyKeyboardMarkup,
    Update,
)
from telegram.ext import (
    Application,
    CallbackQueryHandler,
    CommandHandler,
    ContextTypes,
    ConversationHandler,
    MessageHandler,
    filters,
)

# ─── Paths ────────────────────────────────────────────────────────────────────
BASE_DIR = Path(__file__).parent
LEDGER_PATH = BASE_DIR / "LEDGER.json"
CORP_CONFIG_PATH = BASE_DIR.parent / "corp_config.json"
RBAC_CONFIG_PATH = BASE_DIR / "rbac_config.json"
CULTURE_PATH = BASE_DIR / "CORP_CULTURE.md"

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO,
)
logger = logging.getLogger(__name__)

# ─── Conversation States ──────────────────────────────────────────────────────
(
    NEW_PROJECT_NAME,
    NEW_PROJECT_GOAL,
    NEW_PROJECT_AUDIENCE,
    NEW_PROJECT_BUDGET,
    NEW_PROJECT_CONFIRM,
) = range(5)

REPORT_REVENUE_AMOUNT = 10
REPORT_REVENUE_SOURCE = 11
REPORT_REVENUE_CONFIRM = 12


# ─── RBAC ─────────────────────────────────────────────────────────────────────

def load_rbac_config() -> dict:
    """Load role-based access control configuration."""
    if RBAC_CONFIG_PATH.exists():
        with open(RBAC_CONFIG_PATH, encoding="utf-8") as f:
            return json.load(f)
    # Fallback defaults when rbac_config.json is missing
    return {
        "roles": {
            "super_admin": {
                "label": "超级管理员",
                "permissions": ["all"],
                "users": [],
            },
            "admin": {
                "label": "管理员",
                "permissions": [
                    "new_project",
                    "report_revenue",
                    "view_status",
                    "daily_audit",
                    "score_agent",
                    "view_archive",
                ],
                "users": [],
            },
            "operator": {
                "label": "运营",
                "permissions": [
                    "new_project",
                    "report_revenue",
                    "view_status",
                    "view_archive",
                ],
                "users": [],
            },
            "readonly": {
                "label": "只读",
                "permissions": ["view_status", "view_archive"],
                "users": [],
            },
        },
        "sensitive_ops": [
            "delete_project",
            "archive_project",
            "modify_finance",
            "reset_agent",
            "bounty",
        ],
        "require_approval": ["delete_project", "archive_project", "reset_agent"],
    }


def _allowed_ids() -> list[int]:
    raw = os.environ.get("TELEGRAM_ALLOWED_USERS", "")
    return [int(x.strip()) for x in raw.split(",") if x.strip().isdigit()]


def get_user_role(user_id: int, rbac: dict) -> str | None:
    """Return the role name for a Telegram user ID, or None if not authorised."""
    # Check explicitly configured roles first
    for role_name, role_data in rbac["roles"].items():
        if user_id in role_data.get("users", []):
            return role_name

    # Fall back to TELEGRAM_ALLOWED_USERS environment variable
    ids = _allowed_ids()
    if ids and user_id == ids[0]:
        return "super_admin"
    if user_id in ids:
        return "admin"

    return None


def has_permission(user_id: int, permission: str, rbac: dict) -> bool:
    """Return True if the user holds the requested permission."""
    role = get_user_role(user_id, rbac)
    if role is None:
        return False
    perms = rbac["roles"].get(role, {}).get("permissions", [])
    return "all" in perms or permission in perms


def is_sensitive_op(operation: str, rbac: dict) -> bool:
    return operation in rbac.get("sensitive_ops", [])


def requires_approval(operation: str, rbac: dict) -> bool:
    return operation in rbac.get("require_approval", [])


# ─── Keyboards ────────────────────────────────────────────────────────────────

def main_keyboard() -> ReplyKeyboardMarkup:
    """Bottom persistent keyboard with one-tap command shortcuts."""
    keyboard = [
        [KeyboardButton("🚀 /新项目"), KeyboardButton("💰 /汇报营收")],
        [KeyboardButton("📊 /团队状态"), KeyboardButton("🗓 /日报")],
        [KeyboardButton("📁 /归档列表"), KeyboardButton("❓ /帮助")],
    ]
    return ReplyKeyboardMarkup(keyboard, resize_keyboard=True, one_time_keyboard=False)


def confirmation_keyboard(action: str, payload: str = "") -> InlineKeyboardMarkup:
    """Inline yes/no keyboard for confirming a sensitive action."""
    return InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton("✅ 确认", callback_data=f"confirm:{action}:{payload}"),
                InlineKeyboardButton("❌ 取消", callback_data=f"cancel:{action}"),
            ]
        ]
    )


def approval_keyboard(request_id: str) -> InlineKeyboardMarkup:
    """Inline approve/reject keyboard sent to super_admins for pending requests."""
    return InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton("✅ 批准", callback_data=f"approve:{request_id}"),
                InlineKeyboardButton("❌ 拒绝", callback_data=f"reject:{request_id}"),
            ]
        ]
    )


def project_action_keyboard(project_name: str) -> InlineKeyboardMarkup:
    """Quick-action buttons for a specific project."""
    return InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton("🔬 Scout 分析", callback_data=f"run_scout:{project_name}"),
                InlineKeyboardButton("📈 CMO 方案", callback_data=f"run_cmo:{project_name}"),
            ],
            [
                InlineKeyboardButton("🏗 架构设计", callback_data=f"run_arch:{project_name}"),
                InlineKeyboardButton("👔 CEO 审批", callback_data=f"run_ceo:{project_name}"),
            ],
            [
                InlineKeyboardButton("📦 归档项目", callback_data=f"archive_project:{project_name}"),
                InlineKeyboardButton("🗑 删除项目", callback_data=f"delete_project:{project_name}"),
            ],
        ]
    )


def tips_text() -> str:
    """Return a compact command reference appended after major responses."""
    return (
        "\n\n💡 *常用指令速查*\n"
        "• `/新项目` — 发起新 SaaS 项目（引导式）\n"
        "• `/汇报营收 <金额> <来源>` — 上报项目收益\n"
        "• `/团队状态` — 查看 Agent 状态与金库\n"
        "• `/日报` — 触发每日财务审计\n"
        "• `/评分 <agent> <1-10> <理由>` — 给 Agent 打分\n"
        "• `/归档列表` — 查看已归档项目\n"
        "• `/帮助` — 显示完整帮助"
    )


# ─── Finance helpers ──────────────────────────────────────────────────────────

def load_ledger() -> dict:
    if not LEDGER_PATH.exists():
        return {}
    with open(LEDGER_PATH, encoding="utf-8") as f:
        return json.load(f)


def format_ledger(ledger: dict) -> str:
    treasury = ledger.get("treasury", "N/A")
    level = ledger.get("maturity_level", "N/A")
    status = ledger.get("status", "N/A")
    agents = ledger.get("agents", {})

    lines = [
        "🏦 *公司状态报告*",
        f"金库: `{treasury}` pts  |  阶段: `{level}`  |  运营: `{status}`",
        "",
        "*Agent 积分一览:*",
    ]
    for agent_id, data in agents.items():
        pts = data.get("points", 0)
        gen = data.get("generation", 1)
        emoji = "✅" if pts > 50 else ("⚠️" if pts > 0 else "❌")
        lines.append(f"{emoji} `{agent_id}` — {pts} pts (G{gen})")
    return "\n".join(lines)


def run_finance_cmd(args: list[str]) -> str:
    """Run manage_finance.py with the given arguments and return stdout."""
    script = str(BASE_DIR / "manage_finance.py")
    result = subprocess.run(
        ["python3", script] + args,
        capture_output=True,
        text=True,
        timeout=30,
    )
    return (result.stdout or result.stderr or "（无输出）").strip()


# ─── Auth guard ───────────────────────────────────────────────────────────────

async def auth_guard(update: Update, permission: str) -> bool:
    """Send a denial message and return False when the user lacks permission."""
    rbac = load_rbac_config()
    user_id = update.effective_user.id
    if not has_permission(user_id, permission, rbac):
        role = get_user_role(user_id, rbac)
        if role is None:
            msg = "⛔ 你没有访问权限。请联系超级管理员将你的 Telegram ID 加入允许列表。"
        else:
            role_label = rbac["roles"][role].get("label", role)
            msg = f"⛔ 你的角色 *{role_label}* 没有 `{permission}` 权限。"
        await update.effective_message.reply_text(msg, parse_mode="Markdown")
        return False
    return True


# ─── Command Handlers ─────────────────────────────────────────────────────────

async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Welcome message with role info and main keyboard."""
    user = update.effective_user
    rbac = load_rbac_config()
    role_name = get_user_role(user.id, rbac)
    if role_name:
        role_label = rbac["roles"].get(role_name, {}).get("label", role_name)
    else:
        role_label = "未授权访客"

    text = (
        f"👋 你好，{user.first_name}！\n\n"
        "欢迎使用 *Profit-Corp 指挥中心* 🚀\n"
        f"你的角色：*{role_label}*\n\n"
        "使用底部快捷键盘或直接输入指令来控制你的 Agent 团队。"
    ) + tips_text()

    await update.message.reply_text(
        text, parse_mode="Markdown", reply_markup=main_keyboard()
    )


async def cmd_help(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Show full command reference."""
    text = (
        "📖 *Profit-Corp 指令手册*\n\n"
        "*📂 项目管理*\n"
        "• `/新项目` — 启动交互式新项目引导向导\n"
        "• `/归档列表` — 查看所有已归档项目\n"
        "• `/归档项目 <name>` — 归档指定项目（需审批）\n"
        "• `/删除项目 <name>` — 删除指定项目（需超管审批）\n\n"
        "*💰 财务*\n"
        "• `/汇报营收 <金额> <来源>` — 上报收益（例: `/汇报营收 500 用户订阅`）\n"
        "• `/发放奖金 <金额> <agent> <任务>` — 从金库发放奖金\n"
        "• `/日报` — 执行每日财务审计\n\n"
        "*👥 团队*\n"
        "• `/团队状态` — 查看 Agent 与金库状态\n"
        "• `/评分 <agent> <1-10> <理由>` — 给 Agent 打分\n"
        "• `/重置agent <agent>` — 触发 Agent 重置（需超管审批）\n\n"
        "*⚙️ 系统*\n"
        "• `/帮助` — 显示此帮助\n"
        "• `/状态` — 同 /团队状态\n"
        "• `/start` — 重新显示欢迎界面\n"
    )
    await update.message.reply_text(
        text, parse_mode="Markdown", reply_markup=main_keyboard()
    )


async def cmd_status(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Display team and treasury status."""
    if not await auth_guard(update, "view_status"):
        return
    ledger = load_ledger()
    if not ledger:
        await update.message.reply_text(
            "❌ 无法读取账本，请确认 `shared/LEDGER.json` 存在。",
            reply_markup=main_keyboard(),
        )
        return
    text = format_ledger(ledger) + tips_text()
    await update.message.reply_text(
        text, parse_mode="Markdown", reply_markup=main_keyboard()
    )


async def cmd_daily_audit(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Trigger daily financial audit with confirmation."""
    if not await auth_guard(update, "daily_audit"):
        return
    await update.message.reply_text(
        "⚠️ 确认执行每日审计？这将扣除所有 Agent 的日常运营费用。",
        reply_markup=confirmation_keyboard("daily_audit", ""),
    )


# ─── /新项目 Wizard ────────────────────────────────────────────────────────────

async def cmd_new_project_start(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> int:
    """Begin the interactive new-project onboarding wizard."""
    if not await auth_guard(update, "new_project"):
        return ConversationHandler.END

    await update.effective_message.reply_text(
        "🚀 *启动新项目向导*\n\n"
        "我将引导你逐步完成项目信息采集，无需填写复杂参数表单，只需回复文字即可。\n\n"
        "随时输入 /cancel 可退出向导。\n\n"
        "第 1／4 步：请输入项目名称（例如：TaskFlow Pro）",
        parse_mode="Markdown",
    )
    return NEW_PROJECT_NAME


async def new_project_name(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> int:
    context.user_data["project_name"] = update.message.text.strip()
    await update.message.reply_text(
        f"✅ 项目名：*{context.user_data['project_name']}*\n\n"
        "第 2／4 步：这个项目要解决什么核心问题？\n（用一两句话描述用户痛点，例如：团队缺乏轻量级任务跟踪工具）",
        parse_mode="Markdown",
    )
    return NEW_PROJECT_GOAL


async def new_project_goal(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> int:
    context.user_data["project_goal"] = update.message.text.strip()
    await update.message.reply_text(
        "第 3／4 步：你的目标用户是谁？\n（例如：独立开发者、中小企业财务团队、电商运营等）"
    )
    return NEW_PROJECT_AUDIENCE


async def new_project_audience(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> int:
    context.user_data["project_audience"] = update.message.text.strip()
    await update.message.reply_text(
        "第 4／4 步：你愿意为这个项目分配多少初始预算？\n（以积分为单位，例如：200）"
    )
    return NEW_PROJECT_BUDGET


async def new_project_budget(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> int:
    budget_str = update.message.text.strip()
    if not budget_str.isdigit():
        await update.message.reply_text("⚠️ 请输入纯数字作为积分预算，例如：200")
        return NEW_PROJECT_BUDGET

    context.user_data["project_budget"] = int(budget_str)
    data = context.user_data
    summary = (
        "📋 *项目信息确认*\n\n"
        f"• 项目名称：*{data['project_name']}*\n"
        f"• 核心问题：{data['project_goal']}\n"
        f"• 目标用户：{data['project_audience']}\n"
        f"• 初始预算：{data['project_budget']} pts\n\n"
        "确认后，系统会自动保存项目简报，Scout 即可开始市场调研。"
    )
    await update.message.reply_text(
        summary,
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(
            [
                [
                    InlineKeyboardButton("✅ 确认开启", callback_data="new_project_confirm"),
                    InlineKeyboardButton("❌ 放弃", callback_data="new_project_cancel"),
                ]
            ]
        ),
    )
    return NEW_PROJECT_CONFIRM


async def new_project_confirm_callback(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> int:
    query = update.callback_query
    await query.answer()

    if query.data == "new_project_cancel":
        await query.edit_message_text("🚫 项目创建已取消。")
        return ConversationHandler.END

    data = context.user_data
    project_name = data.get("project_name", "unnamed_project")
    project_goal = data.get("project_goal", "")
    project_audience = data.get("project_audience", "")
    project_budget = data.get("project_budget", 0)

    # Save project brief to shared/
    safe_name = project_name.replace(" ", "_").replace("/", "_")
    brief_path = BASE_DIR / f"PROJECT_BRIEF_{safe_name}.md"
    brief_content = (
        f"# Project Brief: {project_name}\n\n"
        f"**创建时间**: {datetime.now().strftime('%Y-%m-%d %H:%M')}\n"
        f"**核心问题**: {project_goal}\n"
        f"**目标用户**: {project_audience}\n"
        f"**初始预算**: {project_budget} pts\n\n"
        "## 执行状态\n"
        "- [ ] Scout 市场调研\n"
        "- [ ] CMO 市场方案\n"
        "- [ ] Arch 技术规格\n"
        "- [ ] CEO 决策\n"
        "- [ ] 财务审计\n"
    )
    try:
        brief_path.write_text(brief_content, encoding="utf-8")
        saved_msg = f"✅ 项目简报已保存至 `shared/{brief_path.name}`"
    except Exception as exc:
        saved_msg = f"⚠️ 保存简报失败：{exc}"

    text = (
        f"🎉 *{project_name}* 项目已创建！\n\n"
        f"{saved_msg}\n\n"
        "🤖 在 OpenClaw 控制面板运行以下命令启动调研：\n"
        f"```\nnode openclaw.mjs agent run scout "
        f"\"为 {project_name} 项目扫描市场机会\"\n```"
    ) + tips_text()

    await query.edit_message_text(text, parse_mode="Markdown")
    await query.message.reply_text(
        "项目已就绪，使用下方快捷键继续操作：",
        reply_markup=main_keyboard(),
    )
    return ConversationHandler.END


async def new_project_cancel(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> int:
    await update.effective_message.reply_text(
        "🚫 项目创建已取消。", reply_markup=main_keyboard()
    )
    return ConversationHandler.END


# ─── /汇报营收 Wizard ─────────────────────────────────────────────────────────

async def cmd_report_revenue_start(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> int:
    """Begin revenue reporting wizard (or handle inline args directly)."""
    if not await auth_guard(update, "report_revenue"):
        return ConversationHandler.END

    # Support shorthand: /汇报营收 500 用户订阅
    args = context.args
    if args and len(args) >= 2 and args[0].isdigit():
        context.user_data["revenue_amount"] = int(args[0])
        context.user_data["revenue_source"] = " ".join(args[1:])
        return await _revenue_confirm_step(update, context)

    await update.effective_message.reply_text(
        "💰 *营收上报向导*\n\n"
        "第 1／2 步：请输入本次营收金额（积分，例如：500）",
        parse_mode="Markdown",
    )
    return REPORT_REVENUE_AMOUNT


async def revenue_amount(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> int:
    if not update.message.text.strip().isdigit():
        await update.message.reply_text("⚠️ 请输入纯数字，例如：500")
        return REPORT_REVENUE_AMOUNT
    context.user_data["revenue_amount"] = int(update.message.text.strip())
    await update.message.reply_text(
        "第 2／2 步：营收来源是什么？（例如：用户订阅、广告收入、一次性付款等）"
    )
    return REPORT_REVENUE_SOURCE


async def revenue_source(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> int:
    context.user_data["revenue_source"] = update.message.text.strip()
    return await _revenue_confirm_step(update, context)


async def _revenue_confirm_step(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> int:
    amount = context.user_data["revenue_amount"]
    source = context.user_data["revenue_source"]
    payload = f"{amount}|{source}"
    text = (
        "💰 *营收确认*\n\n"
        f"• 金额：*{amount}* pts\n"
        f"• 来源：{source}\n\n"
        "确认后，账本将自动更新，相关 Agent 将获得分红。"
    )
    await update.effective_message.reply_text(
        text,
        parse_mode="Markdown",
        reply_markup=confirmation_keyboard("report_revenue", payload),
    )
    return REPORT_REVENUE_CONFIRM


async def revenue_confirm_placeholder(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> int:
    # Actual confirmation is handled by the global CallbackQueryHandler
    return ConversationHandler.END


# ─── Inline Keyboard Callbacks ────────────────────────────────────────────────

async def callback_handler(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> None:
    """Central dispatcher for all inline-keyboard callbacks."""
    query = update.callback_query
    await query.answer()
    data = query.data

    if data.startswith("confirm:"):
        _, action, payload = data.split(":", 2)
        await _handle_confirm(query, action, payload, context)

    elif data.startswith("cancel:"):
        action = data.split(":", 1)[1]
        await query.edit_message_text(
            f"🚫 操作 `{action}` 已取消。", parse_mode="Markdown"
        )

    elif data.startswith("approve:"):
        request_id = data.split(":", 1)[1]
        await _handle_approve(query, request_id, context)

    elif data.startswith("reject:"):
        request_id = data.split(":", 1)[1]
        await _handle_reject(query, request_id, context)

    elif data.startswith("run_scout:"):
        project = data.split(":", 1)[1]
        await query.edit_message_text(
            f"🔬 Scout 将分析 *{project}*\n\n"
            "请在 OpenClaw 控制面板运行：\n"
            f"```\nnode openclaw.mjs agent run scout "
            f"\"为 {project} 扫描市场\"\n```",
            parse_mode="Markdown",
        )

    elif data.startswith("run_cmo:"):
        project = data.split(":", 1)[1]
        await query.edit_message_text(
            f"📈 CMO 将制定 *{project}* 的市场方案\n\n"
            "请在 OpenClaw 控制面板运行：\n"
            f"```\nnode openclaw.mjs agent run cmo "
            f"\"为 {project} 制定市场方案\"\n```",
            parse_mode="Markdown",
        )

    elif data.startswith("run_arch:"):
        project = data.split(":", 1)[1]
        await query.edit_message_text(
            f"🏗 Arch 将设计 *{project}* 的技术规格\n\n"
            "请在 OpenClaw 控制面板运行：\n"
            f"```\nnode openclaw.mjs agent run arch "
            f"\"为 {project} 起草技术规格\"\n```",
            parse_mode="Markdown",
        )

    elif data.startswith("run_ceo:"):
        project = data.split(":", 1)[1]
        await query.edit_message_text(
            f"👔 CEO 将审批 *{project}*\n\n"
            "请在 OpenClaw 控制面板运行：\n"
            f"```\nnode openclaw.mjs agent run ceo "
            f"\"对 {project} 做出 GO/NO-GO 决策\"\n```",
            parse_mode="Markdown",
        )

    elif data.startswith("archive_project:"):
        project = data.split(":", 1)[1]
        await _handle_governance_action(
            query, context, "archive_project", project
        )

    elif data.startswith("delete_project:"):
        project = data.split(":", 1)[1]
        await _handle_governance_action(
            query, context, "delete_project", project
        )


async def _handle_confirm(query, action: str, payload: str, context) -> None:
    """Execute a confirmed action."""
    if action == "report_revenue":
        amount, source = payload.split("|", 1)
        try:
            output = run_finance_cmd(["revenue", amount, "telegram", source])
            ledger = load_ledger()
            text = (
                "✅ *营收已记录！*\n\n"
                f"```\n{output}\n```\n\n"
                + format_ledger(ledger)
            ) + tips_text()
        except Exception as exc:
            text = f"❌ 记录失败：{exc}"
        await query.edit_message_text(text, parse_mode="Markdown")

    elif action == "daily_audit":
        try:
            output = run_finance_cmd(["audit"])
            ledger = load_ledger()
            text = (
                "🗓 *审计完成！*\n\n"
                f"```\n{output}\n```\n\n"
                + format_ledger(ledger)
            ) + tips_text()
        except Exception as exc:
            text = f"❌ 审计失败：{exc}"
        await query.edit_message_text(text, parse_mode="Markdown")

    elif action == "score_agent":
        agent, score_str, reason = payload.split("|", 2)
        try:
            output = run_finance_cmd(["score", agent, score_str, reason])
            text = f"🎯 *评分已提交！*\n\n```\n{output}\n```" + tips_text()
        except Exception as exc:
            text = f"❌ 评分失败：{exc}"
        await query.edit_message_text(text, parse_mode="Markdown")

    elif action == "bounty":
        amount, agent, task = payload.split("|", 2)
        try:
            output = run_finance_cmd(["bounty", amount, agent, task])
            text = f"🎯 *奖金已发放！*\n\n```\n{output}\n```" + tips_text()
        except Exception as exc:
            text = f"❌ 奖金发放失败：{exc}"
        await query.edit_message_text(text, parse_mode="Markdown")

    elif action == "reset_agent":
        agent = payload
        await query.edit_message_text(
            f"🔄 Agent `{agent}` 重置请求已触发。\n"
            "请前往 OpenClaw 控制面板确认执行。",
            parse_mode="Markdown",
        )

    else:
        await query.edit_message_text(
            f"✅ 操作 `{action}` 已确认执行。", parse_mode="Markdown"
        )


async def _handle_governance_action(
    query, context, operation: str, target: str
) -> None:
    """Route a governance action through RBAC and approval flow if needed."""
    rbac = load_rbac_config()
    user_id = query.from_user.id
    if not has_permission(user_id, "view_status", rbac):
        await query.edit_message_text("⛔ 权限不足。")
        return
    if requires_approval(operation, rbac):
        request_id = await _create_approval_request(
            context, user_id, operation, target, query.message.chat_id
        )
        await query.edit_message_text(
            f"📨 请求已提交，等待超级管理员审批（ID: `{request_id}`）。",
            parse_mode="Markdown",
        )
    else:
        await query.edit_message_text(
            f"✅ 操作 `{operation}` 针对 `{target}` 已执行。",
            parse_mode="Markdown",
        )


# ─── Approval Helpers ─────────────────────────────────────────────────────────

async def _create_approval_request(
    context,
    requester_id: int,
    operation: str,
    target: str,
    chat_id: int,
) -> str:
    """Store a pending request and notify all super_admins."""
    request_id = f"{operation}_{target}_{int(datetime.now().timestamp())}"
    if "approval_requests" not in context.bot_data:
        context.bot_data["approval_requests"] = {}
    context.bot_data["approval_requests"][request_id] = {
        "operation": operation,
        "target": target,
        "requester": requester_id,
        "chat_id": chat_id,
        "status": "pending",
        "created_at": datetime.now().isoformat(),
    }

    rbac = load_rbac_config()
    super_admins: list[int] = list(rbac["roles"].get("super_admin", {}).get("users", []))
    ids = _allowed_ids()
    if ids:
        super_admins = list(set(super_admins + [ids[0]]))

    for admin_id in super_admins:
        try:
            await context.bot.send_message(
                chat_id=admin_id,
                text=(
                    "🔔 *待审批请求*\n\n"
                    f"• 操作：`{operation}`\n"
                    f"• 目标：`{target}`\n"
                    f"• 申请人 ID：`{requester_id}`\n"
                    f"• 请求 ID：`{request_id}`"
                ),
                parse_mode="Markdown",
                reply_markup=approval_keyboard(request_id),
            )
        except Exception:
            pass

    return request_id


async def _handle_approve(query, request_id: str, context) -> None:
    requests = context.bot_data.get("approval_requests", {})
    req = requests.get(request_id)
    if not req:
        await query.edit_message_text("❌ 未找到该审批请求。")
        return
    req["status"] = "approved"
    await query.edit_message_text(
        f"✅ 请求 `{request_id}` 已批准。\n"
        f"操作 `{req['operation']}` 针对 `{req['target']}` 将执行。",
        parse_mode="Markdown",
    )
    try:
        await context.bot.send_message(
            chat_id=req["chat_id"],
            text=f"✅ 你提交的 `{req['operation']}` 请求已获批准，正在执行。",
            parse_mode="Markdown",
        )
    except Exception:
        pass


async def _handle_reject(query, request_id: str, context) -> None:
    requests = context.bot_data.get("approval_requests", {})
    req = requests.get(request_id)
    if not req:
        await query.edit_message_text("❌ 未找到该审批请求。")
        return
    req["status"] = "rejected"
    await query.edit_message_text(
        f"❌ 请求 `{request_id}` 已拒绝。", parse_mode="Markdown"
    )
    try:
        await context.bot.send_message(
            chat_id=req["chat_id"],
            text=f"❌ 你提交的 `{req['operation']}` 请求已被拒绝。",
            parse_mode="Markdown",
        )
    except Exception:
        pass


# ─── Additional Commands ──────────────────────────────────────────────────────

async def cmd_score_agent(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> None:
    """/评分 <agent> <score> <reason>"""
    if not await auth_guard(update, "score_agent"):
        return
    args = context.args
    if len(args) < 3:
        await update.message.reply_text(
            "⚠️ 用法：`/评分 <agent> <1-10> <理由>`\n"
            "例：`/评分 scout 8 市场调研质量高`",
            parse_mode="Markdown",
        )
        return
    agent, score_str, *reason_parts = args
    reason = " ".join(reason_parts)
    if not score_str.isdigit() or not (1 <= int(score_str) <= 10):
        await update.message.reply_text("⚠️ 评分必须是 1 到 10 之间的整数。")
        return
    payload = f"{agent}|{score_str}|{reason}"
    await update.message.reply_text(
        f"🎯 确认给 `{agent}` 打 *{score_str}* 分？\n理由：{reason}",
        parse_mode="Markdown",
        reply_markup=confirmation_keyboard("score_agent", payload),
    )


async def cmd_bounty(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> None:
    """/发放奖金 <amount> <agent> <task>"""
    if not await auth_guard(update, "daily_audit"):
        return
    args = context.args
    if len(args) < 3:
        await update.message.reply_text(
            "⚠️ 用法：`/发放奖金 <金额> <agent> <任务说明>`\n"
            "例：`/发放奖金 100 scout 完成竞品调研`",
            parse_mode="Markdown",
        )
        return
    amount, agent, *task_parts = args
    task = " ".join(task_parts)
    if not amount.isdigit():
        await update.message.reply_text("⚠️ 金额必须为正整数。")
        return
    payload = f"{amount}|{agent}|{task}"
    await update.message.reply_text(
        f"🎯 确认从金库拨出 *{amount}* pts 给 `{agent}`？\n任务：{task}",
        parse_mode="Markdown",
        reply_markup=confirmation_keyboard("bounty", payload),
    )


async def cmd_archive_list(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> None:
    """List archived projects."""
    if not await auth_guard(update, "view_archive"):
        return
    archives_dir = BASE_DIR.parent / "archives"
    if not archives_dir.exists() or not any(archives_dir.iterdir()):
        await update.message.reply_text(
            "📁 暂无归档项目。\n使用 `/归档项目 <name>` 来归档一个项目。",
            reply_markup=main_keyboard(),
        )
        return
    items = sorted(d.name for d in archives_dir.iterdir() if d.is_dir())
    text = "📁 *已归档项目列表*\n\n" + "\n".join(f"• `{item}`" for item in items)
    await update.message.reply_text(
        text, parse_mode="Markdown", reply_markup=main_keyboard()
    )


async def cmd_reset_agent(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> None:
    """/重置agent <agent> — requires super_admin approval."""
    if not await auth_guard(update, "score_agent"):
        return
    args = context.args
    if not args:
        await update.message.reply_text(
            "⚠️ 用法：`/重置agent <agent名称>`", parse_mode="Markdown"
        )
        return
    agent = args[0]
    rbac = load_rbac_config()
    user_id = update.effective_user.id
    if requires_approval("reset_agent", rbac):
        request_id = await _create_approval_request(
            context, user_id, "reset_agent", agent, update.effective_chat.id
        )
        await update.message.reply_text(
            f"📨 重置请求已提交（ID: `{request_id}`），等待超级管理员审批。",
            parse_mode="Markdown",
            reply_markup=main_keyboard(),
        )
    else:
        await update.message.reply_text(
            f"⚠️ 确认重置 Agent `{agent}`？",
            parse_mode="Markdown",
            reply_markup=confirmation_keyboard("reset_agent", agent),
        )


async def cmd_delete_project(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> None:
    """/删除项目 <name> — sensitive, requires approval."""
    if not await auth_guard(update, "view_status"):
        return
    args = context.args
    if not args:
        await update.message.reply_text(
            "⚠️ 用法：`/删除项目 <项目名称>`", parse_mode="Markdown"
        )
        return
    project = " ".join(args)
    rbac = load_rbac_config()
    user_id = update.effective_user.id
    if requires_approval("delete_project", rbac):
        request_id = await _create_approval_request(
            context, user_id, "delete_project", project, update.effective_chat.id
        )
        await update.message.reply_text(
            f"📨 删除请求已提交（ID: `{request_id}`），等待超级管理员审批。",
            parse_mode="Markdown",
            reply_markup=main_keyboard(),
        )
    else:
        await update.message.reply_text(
            f"⚠️ 确认删除项目 *{project}*？此操作不可撤销。",
            parse_mode="Markdown",
            reply_markup=confirmation_keyboard("delete_project", project),
        )


async def cmd_archive_project(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> None:
    """/归档项目 <name> — requires approval."""
    if not await auth_guard(update, "view_status"):
        return
    args = context.args
    if not args:
        await update.message.reply_text(
            "⚠️ 用法：`/归档项目 <项目名称>`", parse_mode="Markdown"
        )
        return
    project = " ".join(args)
    rbac = load_rbac_config()
    user_id = update.effective_user.id
    if requires_approval("archive_project", rbac):
        request_id = await _create_approval_request(
            context, user_id, "archive_project", project, update.effective_chat.id
        )
        await update.message.reply_text(
            f"📨 归档请求已提交（ID: `{request_id}`），等待超级管理员审批。",
            parse_mode="Markdown",
            reply_markup=main_keyboard(),
        )
    else:
        await update.message.reply_text(
            f"📦 确认归档项目 *{project}*？",
            parse_mode="Markdown",
            reply_markup=confirmation_keyboard("archive_project", project),
        )


async def handle_text(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> None:
    """Resolve bottom-keyboard shortcut aliases to their command handlers."""
    text = update.message.text
    aliases: dict[str, any] = {
        "🚀 /新项目": cmd_new_project_start,
        "💰 /汇报营收": cmd_report_revenue_start,
        "📊 /团队状态": cmd_status,
        "🗓 /日报": cmd_daily_audit,
        "📁 /归档列表": cmd_archive_list,
        "❓ /帮助": cmd_help,
    }
    if text in aliases:
        await aliases[text](update, context)
    else:
        await update.message.reply_text(
            "💬 请使用底部快捷键盘或输入 `/帮助` 查看所有可用指令。",
            reply_markup=main_keyboard(),
        )


# ─── Bot Setup ────────────────────────────────────────────────────────────────

async def post_init(application: Application) -> None:
    """Register the bot's command list in the Telegram UI."""
    commands = [
        BotCommand("start", "🚀 启动指挥中心"),
        BotCommand("xin_xiang_mu", "🆕 新项目引导向导"),
        BotCommand("hui_bao_ying_shou", "💰 汇报营收"),
        BotCommand("tuan_dui_zhuang_tai", "📊 团队状态"),
        BotCommand("ri_bao", "🗓 每日财务审计"),
        BotCommand("ping_fen", "🎯 给 Agent 打分"),
        BotCommand("fa_fang_jiang_jin", "💎 发放奖金"),
        BotCommand("gui_dang_lie_biao", "📁 归档列表"),
        BotCommand("gui_dang_xiang_mu", "📦 归档项目（需审批）"),
        BotCommand("shan_chu_xiang_mu", "🗑 删除项目（需审批）"),
        BotCommand("chong_zhi_agent", "🔄 重置 Agent（需超管审批）"),
        BotCommand("help", "❓ 完整指令帮助"),
    ]
    await application.bot.set_my_commands(commands)


def build_app(token: str) -> Application:
    """Assemble and return the fully configured Application instance."""
    app = Application.builder().token(token).post_init(post_init).build()

    # ── /新项目 ConversationHandler ──
    new_project_conv = ConversationHandler(
        entry_points=[
            CommandHandler(["xin_xiang_mu"], cmd_new_project_start),
            MessageHandler(filters.Regex(r"^🚀 /新项目$"), cmd_new_project_start),
        ],
        states={
            NEW_PROJECT_NAME: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, new_project_name)
            ],
            NEW_PROJECT_GOAL: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, new_project_goal)
            ],
            NEW_PROJECT_AUDIENCE: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, new_project_audience)
            ],
            NEW_PROJECT_BUDGET: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, new_project_budget)
            ],
            NEW_PROJECT_CONFIRM: [
                CallbackQueryHandler(
                    new_project_confirm_callback, pattern="^new_project_"
                )
            ],
        },
        fallbacks=[CommandHandler("cancel", new_project_cancel)],
    )

    # ── /汇报营收 ConversationHandler ──
    revenue_conv = ConversationHandler(
        entry_points=[
            CommandHandler(["hui_bao_ying_shou"], cmd_report_revenue_start),
            MessageHandler(filters.Regex(r"^💰 /汇报营收$"), cmd_report_revenue_start),
        ],
        states={
            REPORT_REVENUE_AMOUNT: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, revenue_amount)
            ],
            REPORT_REVENUE_SOURCE: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, revenue_source)
            ],
            REPORT_REVENUE_CONFIRM: [
                CallbackQueryHandler(
                    revenue_confirm_placeholder,
                    pattern="^confirm:report_revenue",
                )
            ],
        },
        fallbacks=[CommandHandler("cancel", new_project_cancel)],
    )

    app.add_handler(new_project_conv)
    app.add_handler(revenue_conv)

    # ── Standard commands ──
    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler(["help"], cmd_help))
    app.add_handler(CommandHandler(["tuan_dui_zhuang_tai", "status"], cmd_status))
    app.add_handler(CommandHandler(["ri_bao", "audit"], cmd_daily_audit))
    app.add_handler(CommandHandler(["ping_fen", "score"], cmd_score_agent))
    app.add_handler(CommandHandler(["fa_fang_jiang_jin", "bounty"], cmd_bounty))
    app.add_handler(CommandHandler(["gui_dang_lie_biao", "archives"], cmd_archive_list))
    app.add_handler(CommandHandler(["gui_dang_xiang_mu", "archive"], cmd_archive_project))
    app.add_handler(CommandHandler(["shan_chu_xiang_mu", "delete"], cmd_delete_project))
    app.add_handler(CommandHandler(["chong_zhi_agent", "reset_agent"], cmd_reset_agent))

    # ── Global inline-keyboard handler (must come after conversation handlers) ──
    app.add_handler(CallbackQueryHandler(callback_handler))

    # ── Plain text / keyboard alias handler ──
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))

    return app


def main() -> None:
    token = os.environ.get("TELEGRAM_BOT_TOKEN")
    if not token:
        print("❌ 错误：请设置环境变量 TELEGRAM_BOT_TOKEN")
        print("  export TELEGRAM_BOT_TOKEN=your_token_here")
        raise SystemExit(1)

    app = build_app(token)
    logger.info("🤖 Profit-Corp Telegram Bot 已启动，按 Ctrl+C 退出")
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
