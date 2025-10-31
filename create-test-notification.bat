@echo off
echo Creating test notification for user b658eca1-3cc1-48b2-bd3c-33b81fab5a0f...
curl.exe -X POST "https://vmypotfsyrvuublyddyt.supabase.co/rest/v1/notifications" ^
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs" ^
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs" ^
  -H "Content-Type: application/json" ^
  -H "Prefer: return=representation" ^
  -d "{\"title\":\"Test Push Notification\",\"body\":\"Testing push notification system for user yousafali\",\"created_by\":\"e1fdaee2-97f0-4fc1-872f-9d99c6bd684b\",\"target_type\":\"specific_users\",\"target_users\":[\"b658eca1-3cc1-48b2-bd3c-33b81fab5a0f\"],\"icon\":\"/icons/icon-192x192.png\",\"data\":{\"url\":\"/notifications\",\"test\":true}}"

echo.
echo Done! The notification should now be queued.
