@echo off
title Aqura ERP Bridge - Data Manager Setup
color 0A
chcp 65001 >nul 2>nul

:: ============================================================
:: Aqura Data Manager - One-Click Setup
:: 
:: Just double-click this file. It handles EVERYTHING:
::   1. Auto-elevates to Administrator
::   2. Checks if Node.js is installed → installs if missing
::   3. Creates C:\erp-api folder
::   4. Copies the wizard file
::   5. Opens the setup wizard in your browser
::
:: No technical knowledge needed. Just double-click and follow
:: the wizard in your browser.
:: ============================================================

:: ─────────────────────────────────────────────────────────────
:: STEP 1: Auto-elevate to Administrator (UAC prompt)
:: ─────────────────────────────────────────────────────────────
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo.
    echo ╔══════════════════════════════════════════════════╗
    echo ║  Requesting Administrator permissions...         ║
    echo ║  Please click YES on the popup.                  ║
    echo ╚══════════════════════════════════════════════════╝
    echo.
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "%~dp0", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    cd /d "%~dp0"

:: ─────────────────────────────────────────────────────────────
:: BANNER
:: ─────────────────────────────────────────────────────────────
cls
echo.
echo   ╔══════════════════════════════════════════════════════╗
echo   ║                                                      ║
echo   ║     🏗️  Aqura ERP Bridge - Data Manager Setup       ║
echo   ║                                                      ║
echo   ║     One-click setup for ERP bridge connection        ║
echo   ║     This will install everything automatically       ║
echo   ║                                                      ║
echo   ╚══════════════════════════════════════════════════════╝
echo.
echo   Running as Administrator ✅
echo.

:: ─────────────────────────────────────────────────────────────
:: STEP 2: Check if Node.js is installed
:: ─────────────────────────────────────────────────────────────
echo   [1/5] Checking Node.js...
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo   ⚠️  Node.js is NOT installed.
    echo   📥 Downloading Node.js v20.11.1 installer...
    echo.
    
    :: Download Node.js MSI
    curl -Lo "%~dp0node-setup.msi" "https://nodejs.org/dist/v20.11.1/node-v20.11.1-x64.msi"
    
    if not exist "%~dp0node-setup.msi" (
        echo.
        echo   ❌ ERROR: Failed to download Node.js.
        echo   Please check your internet connection and try again.
        echo.
        pause
        exit /B 1
    )
    
    echo.
    echo   📦 Installing Node.js silently... (this takes 1-2 minutes)
    echo.
    
    :: Silent install
    msiexec /i "%~dp0node-setup.msi" /qn /norestart
    
    :: Wait for install to complete
    timeout /t 5 /nobreak >nul
    
    :: Refresh PATH for this session
    set "PATH=%PATH%;C:\Program Files\nodejs"
    
    :: Clean up installer
    del "%~dp0node-setup.msi" >nul 2>nul
    
    :: Verify
    where node >nul 2>nul
    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo   ❌ ERROR: Node.js installation failed.
        echo   Please install Node.js manually from https://nodejs.org
        echo   Then run this setup again.
        echo.
        pause
        exit /B 1
    )
    
    echo   ✅ Node.js installed successfully!
) else (
    for /f "tokens=*" %%i in ('node --version') do set NODE_VER=%%i
    echo   ✅ Node.js %NODE_VER% is already installed
)

echo.

:: ─────────────────────────────────────────────────────────────
:: STEP 3: Create C:\erp-api folder
:: ─────────────────────────────────────────────────────────────
echo   [2/5] Creating C:\erp-api folder...
if not exist "C:\erp-api" mkdir "C:\erp-api"
echo   ✅ C:\erp-api ready
echo.

:: ─────────────────────────────────────────────────────────────
:: STEP 4: Copy wizard file
:: ─────────────────────────────────────────────────────────────
echo   [3/5] Copying setup wizard...
if exist "%~dp0setup-wizard.js" (
    copy /Y "%~dp0setup-wizard.js" "C:\erp-api\setup-wizard.js" >nul
    echo   ✅ Wizard copied to C:\erp-api\setup-wizard.js
) else (
    echo   ❌ ERROR: setup-wizard.js not found in this folder!
    echo   Make sure setup-wizard.js is next to Setup.bat
    echo.
    pause
    exit /B 1
)
echo.

:: ─────────────────────────────────────────────────────────────
:: STEP 5: Download cloudflared.exe if not present
:: ─────────────────────────────────────────────────────────────
echo   [4/5] Checking cloudflared...
if exist "C:\cloudflared.exe" (
    echo   ✅ cloudflared.exe already exists
) else (
    echo   📥 Downloading cloudflared.exe...
    curl -Lo "C:\cloudflared.exe" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
    if exist "C:\cloudflared.exe" (
        echo   ✅ cloudflared.exe downloaded
    ) else (
        echo   ⚠️  Warning: Could not download cloudflared.exe
        echo   The wizard will try to download it again later.
    )
)
echo.

:: ─────────────────────────────────────────────────────────────
:: STEP 6: Launch the wizard
:: ─────────────────────────────────────────────────────────────
echo   [5/5] Starting setup wizard...
echo.
echo   ╔══════════════════════════════════════════════════════╗
echo   ║                                                      ║
echo   ║   🌐 Your browser will open automatically.          ║
echo   ║                                                      ║
echo   ║   Fill in the configuration and click                ║
echo   ║   "Install Everything"                               ║
echo   ║                                                      ║
echo   ║   DO NOT CLOSE THIS WINDOW until setup is done.     ║
echo   ║                                                      ║
echo   ╚══════════════════════════════════════════════════════╝
echo.

cd /d "C:\erp-api"
node setup-wizard.js

:: ─────────────────────────────────────────────────────────────
:: DONE
:: ─────────────────────────────────────────────────────────────
echo.
echo   ══════════════════════════════════════════════════════
echo   Setup wizard has been closed.
echo   
echo   If everything was successful, this branch is now
echo   connected to the Aqura ERP system.
echo   
echo   You can close this window.
echo   ══════════════════════════════════════════════════════
echo.
pause
