-- Enable pg_cron and set up the push notification cron job
-- Run this in Supabase SQL Editor

-- 1. First check if pg_cron is enabled
SELECT * FROM pg_extension WHERE extname = 'pg_cron';

-- 2. If not enabled, enable it (requires superuser/Pro plan)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 3. Grant necessary permissions
GRANT USAGE ON SCHEMA cron TO postgres;

-- 4. Check if our function exists
SELECT proname FROM pg_proc WHERE proname = 'process_push_notification_queue';

-- 5. Create the function to call the Edge Function
CREATE OR REPLACE FUNCTION process_push_notification_queue()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_response text;
    v_status int;
BEGIN
    -- Call the Edge Function using http extension
    SELECT status, content INTO v_status, v_response
    FROM http_post(
        'https://vmypotfsyrvuublyddyt.supabase.co/functions/v1/process-push-queue',
        '{}',
        'application/json',
        ARRAY[
            http_header('Content-Type', 'application/json')
        ]
    );
    
    -- Log the response
    RAISE LOG 'Push queue processor called - Status: %, Response: %', v_status, v_response;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log errors but don't fail
        RAISE LOG 'Error calling push queue processor: %', SQLERRM;
END;
$$;

-- 6. Enable http extension if not already enabled
CREATE EXTENSION IF NOT EXISTS http;

-- 7. Delete any existing cron jobs for push notifications
SELECT cron.unschedule(jobid) 
FROM cron.job 
WHERE jobname LIKE '%push%';

-- 8. Schedule the cron job to run every 30 seconds
-- Since pg_cron doesn't support seconds, we'll run every minute
SELECT cron.schedule(
    'process-push-notifications',
    '* * * * *', -- Every minute
    'SELECT process_push_notification_queue();'
);

-- 9. Verify the cron job was created
SELECT * FROM cron.job WHERE jobname = 'process-push-notifications';

-- 10. Check recent job runs
SELECT * FROM cron.job_run_details 
WHERE jobid IN (SELECT jobid FROM cron.job WHERE jobname = 'process-push-notifications')
ORDER BY start_time DESC 
LIMIT 10;
