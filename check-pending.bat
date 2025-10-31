@echo off
echo Detailed queue status check...
echo.

REM Get the environment variables
for /f "delims=" %%i in ('type frontend\.env ^| findstr VITE_SUPABASE_URL') do set %%i
for /f "delims=" %%i in ('type frontend\.env ^| findstr VITE_SUPABASE_ANON_KEY') do set %%i

echo Checking pending notifications:
curl -X GET "%VITE_SUPABASE_URL%/rest/v1/notification_queue?select=id,status,next_retry_at,push_subscription_id&status=eq.pending" ^
  -H "apikey: %VITE_SUPABASE_ANON_KEY%" ^
  -H "Authorization: Bearer %VITE_SUPABASE_ANON_KEY%"

echo.
echo.
pause
