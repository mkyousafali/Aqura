@echo off
echo Checking queue payload structure...
echo.

REM Get the environment variables
for /f "delims=" %%i in ('type frontend\.env ^| findstr VITE_SUPABASE_URL') do set %%i
for /f "delims=" %%i in ('type frontend\.env ^| findstr VITE_SUPABASE_ANON_KEY') do set %%i

curl -X GET "%VITE_SUPABASE_URL%/rest/v1/notification_queue?select=id,notification_id,payload&order=created_at.desc&limit=1" ^
  -H "apikey: %VITE_SUPABASE_ANON_KEY%" ^
  -H "Authorization: Bearer %VITE_SUPABASE_ANON_KEY%"

echo.
pause
