@echo off
:: Profit-First SaaS Inc. - Windows Deployment Script

echo 🚀 Deploying Profit-First SaaS Inc...

:: 1. Path detection
set CORP_ROOT=%~dp0
set OPENCLAW_PATH=%CORP_ROOT%..\openclaw.mjs

if not exist "%OPENCLAW_PATH%" (
    echo ❌ Error: openclaw.mjs not found at %OPENCLAW_PATH%
    exit /b 1
)

:: 2. Register agents
for %%a in (scout cmo arch ceo accountant) do (
    echo --- Registering %%a ---
    node "%OPENCLAW_PATH%" agent create %%a --workspace "%CORP_ROOT%workspaces\%%a" -y
)

:: 3. Initialize Finance
echo --- Initializing Ledger ---
python "%CORP_ROOT%shared\manage_finance.py" audit

:: 4. Telegram Bot setup (optional)
echo.
echo --- Telegram Bot Setup ---
python -c "import telegram" >nul 2>&1
if %errorlevel% neq 0 (
    echo ⚠️  python-telegram-bot not found. Installing...
    pip install "python-telegram-bot>=20.0" --quiet
) else (
    echo ✅ python-telegram-bot is installed.
)

echo.
echo To start the Telegram Bot, set your credentials and run:
echo   set TELEGRAM_BOT_TOKEN=^<your_token^>
echo   set TELEGRAM_ALLOWED_USERS=^<your_telegram_user_id^>
echo   python "%CORP_ROOT%shared\telegram_bot.py"
echo.
echo Get your Bot Token from @BotFather on Telegram.
echo Get your User ID from @userinfobot on Telegram.

echo.
echo ✅ Deployment Complete.
pause
