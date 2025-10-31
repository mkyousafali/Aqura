@echo off
echo ========================================
echo Testing Push Notification System
echo ========================================
echo.

REM Get the environment variables
for /f "delims=" %%i in ('type frontend\.env ^| findstr VITE_SUPABASE_URL') do set %%i
for /f "delims=" %%i in ('type frontend\.env ^| findstr VITE_SUPABASE_ANON_KEY') do set %%i

echo Calling process-push-queue Edge Function...
echo.

curl -X POST "%VITE_SUPABASE_URL%/functions/v1/process-push-queue" ^
  -H "Content-Type: application/json" ^
  -H "Authorization: Bearer %VITE_SUPABASE_ANON_KEY%" ^
  -H "apikey: %VITE_SUPABASE_ANON_KEY%" ^
  -d "{}"

echo.
echo.
echo ========================================
echo Test Complete
echo ========================================
pause
