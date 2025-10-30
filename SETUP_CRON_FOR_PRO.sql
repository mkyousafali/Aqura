-- ============================================================
-- SETUP PUSH NOTIFICATION CRON JOB (Supabase Pro)
-- ============================================================
-- Copy and paste this entire script into Supabase SQL Editor
-- This will set up automatic push notification processing

-- Step 1: Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS http;

-- Step 2: Grant permissions
GRANT USAGE ON SCHEMA cron TO postgres;

-- Step 3: Remove any existing push notification cron jobs
DO $$ 
DECLARE
    job_record RECORD;
BEGIN
    FOR job_record IN 
        SELECT jobid, jobname FROM cron.job 
        WHERE jobname LIKE '%push%notification%' OR jobname LIKE '%process-push%'
    LOOP
        PERFORM cron.unschedule(job_record.jobid);
        RAISE NOTICE 'Unscheduled job: % (ID: %)', job_record.jobname, job_record.jobid;
    END LOOP;
END $$;

-- Step 4: Create the function to call the Edge Function
CREATE OR REPLACE FUNCTION process_push_notification_queue()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_response http_response;
    v_supabase_url text := 'https://vmypotfsyrvuublyddyt.supabase.co';
    v_anon_key text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.YkxK0zqLFkuS62t1SHY23Z9tAQqLuPJHoxPvvxKLTGQ';
BEGIN
    -- Call the Edge Function
    SELECT * INTO v_response
    FROM http((
        'POST',
        v_supabase_url || '/functions/v1/process-push-queue',
        ARRAY[
            http_header('Authorization', 'Bearer ' || v_anon_key),
            http_header('Content-Type', 'application/json')
        ],
        'application/json',
        '{}'
    )::http_request);
    
    -- Log success
    IF v_response.status = 200 THEN
        RAISE LOG 'Push queue processed successfully: %', v_response.content;
    ELSE
        RAISE WARNING 'Push queue processing returned status %: %', v_response.status, v_response.content;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG 'Error calling push queue processor: %', SQLERRM;
END;
$$;

-- Step 5: Grant execute permissions
GRANT EXECUTE ON FUNCTION process_push_notification_queue() TO postgres;
GRANT EXECUTE ON FUNCTION process_push_notification_queue() TO service_role;

-- Step 6: Schedule the cron job to run every minute
SELECT cron.schedule(
    'process-push-notifications',
    '* * * * *', -- Every minute (pg_cron doesn't support seconds)
    'SELECT process_push_notification_queue();'
);

-- Step 7: Verify the setup
SELECT 
    'Cron job scheduled successfully!' as message,
    jobid,
    jobname,
    schedule,
    active
FROM cron.job 
WHERE jobname = 'process-push-notifications';

-- Step 8: Test the function immediately (optional)
-- Uncomment the line below to test:
-- SELECT process_push_notification_queue();

-- ============================================================
-- TO CHECK IF IT'S WORKING:
-- ============================================================
-- Run this query after a few minutes to see the cron job history:
-- SELECT * FROM cron.job_run_details 
-- WHERE jobid IN (SELECT jobid FROM cron.job WHERE jobname = 'process-push-notifications')
-- ORDER BY start_time DESC 
-- LIMIT 10;
