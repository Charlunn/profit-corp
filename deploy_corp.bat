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

echo ✅ Deployment Complete.
pause
