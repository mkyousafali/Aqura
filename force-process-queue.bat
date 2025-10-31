@echo off
echo Clearing next_retry_at to force immediate processing...
echo.

REM Get the environment variables
for /f "delims=" %%i in ('type frontend\.env ^| findstr VITE_SUPABASE_URL') do set %%i
for /f "delims=" %%i in ('type frontend\.env ^| findstr VITE_SUPABASE_ANON_KEY') do set %%i

curl -X PATCH "%VITE_SUPABASE_URL%/rest/v1/notification_queue?status=eq.pending" ^
  -H "apikey: %VITE_SUPABASE_ANON_KEY%" ^
  -H "Authorization: Bearer %VITE_SUPABASE_ANON_KEY%" ^
  -H "Content-Type: application/json" ^
  -H "Prefer: return=minimal" ^
  -d "{\"next_retry_at\":null,\"last_attempt_at\":null}"

echo.
echo Done!
pause
