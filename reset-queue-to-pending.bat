@echo off
echo Resetting retry notifications to pending...
echo.

REM Get the environment variables
for /f "delims=" %%i in ('type frontend\.env ^| findstr VITE_SUPABASE_URL') do set %%i
for /f "delims=" %%i in ('type frontend\.env ^| findstr VITE_SUPABASE_ANON_KEY') do set %%i

curl -X PATCH "%VITE_SUPABASE_URL%/rest/v1/notification_queue?status=eq.retry" ^
  -H "apikey: %VITE_SUPABASE_ANON_KEY%" ^
  -H "Authorization: Bearer %VITE_SUPABASE_ANON_KEY%" ^
  -H "Content-Type: application/json" ^
  -H "Prefer: return=representation" ^
  -d "{\"status\":\"pending\",\"retry_count\":0}"

echo.
echo.
echo Done! Now trigger the Edge Function again...
pause
