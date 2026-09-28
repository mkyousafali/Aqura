@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0push-and-deploy.ps1" %*
exit /b %ERRORLEVEL%
