@echo off
echo ========================================
echo Aqura-tunnel Auto-Start Setup
echo ========================================
echo.

REM Get the current directory
set "CURRENT_DIR=%~dp0"
set "EXE_PATH=%CURRENT_DIR%Aqura-tunnel.exe"

echo Current directory: %CURRENT_DIR%
echo Executable path: %EXE_PATH%
echo.

REM Check if executable exists
if not exist "%EXE_PATH%" (
    echo ERROR: Aqura-tunnel.exe not found!
    echo Please make sure this script is in the same folder as Aqura-tunnel.exe
    pause
    exit /b 1
)

echo Creating startup shortcut...
echo.

REM Create VBScript to create shortcut
set "VBSCRIPT=%TEMP%\create_shortcut.vbs"
echo Set oWS = WScript.CreateObject("WScript.Shell") > "%VBSCRIPT%"
echo sLinkFile = oWS.SpecialFolders("Startup") ^& "\Aqura-tunnel.lnk" >> "%VBSCRIPT%"
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> "%VBSCRIPT%"
echo oLink.TargetPath = "%EXE_PATH%" >> "%VBSCRIPT%"
echo oLink.WorkingDirectory = "%CURRENT_DIR%" >> "%VBSCRIPT%"
echo oLink.Description = "Aqura-tunnel ERP Sync Service" >> "%VBSCRIPT%"
echo oLink.Save >> "%VBSCRIPT%"

REM Run VBScript
cscript //nologo "%VBSCRIPT%"
del "%VBSCRIPT%"

echo.
echo ========================================
echo SUCCESS! Aqura-tunnel will now start automatically when Windows starts.
echo ========================================
echo.
echo Shortcut location: %USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup
echo.
echo To disable auto-start:
echo 1. Open the app
echo 2. Uncheck "Start automatically when Windows starts"
echo    OR
echo 3. Delete the shortcut from the Startup folder
echo.
pause
