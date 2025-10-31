@echo off
echo Checking notification queue status...
echo.

REM Get the environment variables
for /f "delims=" %%i in ('type frontend\.env ^| findstr VITE_SUPABASE_URL') do set %%i
for /f "delims=" %%i in ('type frontend\.env ^| findstr VITE_SUPABASE_ANON_KEY') do set %%i

curl -X GET "%VITE_SUPABASE_URL%/rest/v1/notification_queue?select=id,user_id,status,retry_count,created_at&order=created_at.desc&limit=10" ^
  -H "apikey: %VITE_SUPABASE_ANON_KEY%" ^
  -H "Authorization: Bearer %VITE_SUPABASE_ANON_KEY%"

echo.
pause
