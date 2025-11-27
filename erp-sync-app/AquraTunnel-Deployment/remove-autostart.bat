@echo off
echo ========================================
echo Aqura-tunnel Auto-Start Removal
echo ========================================
echo.

REM Get startup folder path
set "STARTUP_FOLDER=%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
set "SHORTCUT_PATH=%STARTUP_FOLDER%\Aqura-tunnel.lnk"

echo Checking for startup shortcut...
echo Location: %SHORTCUT_PATH%
echo.

REM Check if shortcut exists
if exist "%SHORTCUT_PATH%" (
    echo Found Aqura-tunnel startup shortcut
    echo Removing...
    del "%SHORTCUT_PATH%"
    
    if not exist "%SHORTCUT_PATH%" (
        echo.
        echo ========================================
        echo SUCCESS! Auto-start has been disabled.
        echo ========================================
        echo.
        echo Aqura-tunnel will no longer start automatically with Windows.
    ) else (
        echo.
        echo ERROR: Failed to remove shortcut.
        echo You may need to run this script as Administrator.
    )
) else (
    echo.
    echo Aqura-tunnel auto-start is not currently enabled.
    echo Nothing to remove.
)

echo.
pause
