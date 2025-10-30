-- Check if pg_cron extension exists and what jobs are scheduled
-- Run this in Supabase SQL Editor

-- Check if pg_cron extension is installed
SELECT * FROM pg_extension WHERE extname = 'pg_cron';

-- If pg_cron exists, check scheduled jobs
SELECT * FROM cron.job;

-- Check if the process_push_notification_queue function exists
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname LIKE '%push%queue%';
