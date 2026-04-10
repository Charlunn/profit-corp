@echo off
:: Profit-First SaaS Inc. - Windows Deployment Script
:: --------------------------------------------------
:: For full OpenCLAW-native integration (Telegram, webchat, cron),
:: use the new setup script after this:
::
::   setup_corp.sh (via WSL2) - recommended
::
:: See ARCHITECTURE.md for the full OpenCLAW integration guide.

echo Deploying Profit-First SaaS Inc...

:: 1. Path detection
set CORP_ROOT=%~dp0
set OPENCLAW_PATH=%CORP_ROOT%..\openclaw.mjs

if not exist "%OPENCLAW_PATH%" (
    echo Attempting global openclaw command...
    where openclaw >nul 2>&1
    if %errorlevel% == 0 (
        set OPENCLAW_CMD=openclaw
    ) else (
        echo ERROR: openclaw not found. Install it: npm install -g openclaw@latest
        exit /b 1
    )
) else (
    set OPENCLAW_CMD=node "%OPENCLAW_PATH%"
)

:: 2. Register agents using `openclaw agents add`
for %%a in (scout cmo arch ceo accountant) do (
    echo --- Registering %%a ---
    %OPENCLAW_CMD% agents add %%a --workspace "%CORP_ROOT%workspaces\%%a" --non-interactive 2>nul || ^
    %OPENCLAW_CMD% agent create %%a --workspace "%CORP_ROOT%workspaces\%%a" -y 2>nul || ^
    echo   WARNING: Could not register %%a - start gateway first or use setup_corp.sh
)

:: 3. Initialize Finance
echo --- Initializing Ledger ---
python "%CORP_ROOT%shared\manage_finance.py" audit

echo.
echo Deployment Complete.
echo.
echo For full native integration, run: setup_corp.sh (via WSL2)
pause
