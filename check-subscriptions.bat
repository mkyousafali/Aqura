@echo off
echo Checking push subscriptions...
echo.

REM Get the environment variables
for /f "delims=" %%i in ('type frontend\.env ^| findstr VITE_SUPABASE_URL') do set %%i
for /f "delims=" %%i in ('type frontend\.env ^| findstr VITE_SUPABASE_ANON_KEY') do set %%i

curl -X GET "%VITE_SUPABASE_URL%/rest/v1/push_subscriptions?select=id,endpoint,device_type,is_active&user_id=eq.b658eca1-3cc1-48b2-bd3c-33b81fab5a0f&limit=5" ^
  -H "apikey: %VITE_SUPABASE_ANON_KEY%" ^
  -H "Authorization: Bearer %VITE_SUPABASE_ANON_KEY%"

echo.
pause
