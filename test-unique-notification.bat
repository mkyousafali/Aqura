@echo off
echo Creating NEW test notification with unique title...
curl.exe -X POST "https://vmypotfsyrvuublyddyt.supabase.co/rest/v1/notifications" ^
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs" ^
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs" ^
  -H "Content-Type: application/json" ^
  -H "Prefer: return=representation" ^
  -d "{\"title\":\"🎉 UNIQUE TEST %TIME%\",\"message\":\"This is notification %TIME% - If you see this exact text, it works!\",\"created_by\":\"madmin\",\"created_by_name\":\"System Admin\",\"created_by_role\":\"Admin\",\"target_type\":\"specific_users\",\"target_users\":[\"b658eca1-3cc1-48b2-bd3c-33b81fab5a0f\"],\"type\":\"info\",\"priority\":\"high\",\"status\":\"published\"}"

echo.
echo.
echo Waiting 5 seconds for auto-processing...
timeout /t 5 /nobreak
echo.
echo Notification should appear now!
pause
