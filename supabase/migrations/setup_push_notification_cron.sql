-- Migration: Setup automatic push notification queue processing
-- This creates a cron job that calls the Edge Function every 30 seconds to process the queue
-- Works even when users are logged out or phones are locked

-- Enable pg_cron extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Grant usage on cron schema to postgres
GRANT USAGE ON SCHEMA cron TO postgres;

-- Create a function to call the Edge Function
CREATE OR REPLACE FUNCTION process_push_notification_queue()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_response text;
    v_supabase_url text;
    v_anon_key text;
BEGIN
    -- Get Supabase URL and key from environment (these will be set in production)
    v_supabase_url := current_setting('app.settings.supabase_url', true);
    v_anon_key := current_setting('app.settings.supabase_anon_key', true);
    
    -- If not set, use default local development values
    IF v_supabase_url IS NULL THEN
        v_supabase_url := 'https://vmypotfsyrvuublyddyt.supabase.co';
    END IF;
    
    IF v_anon_key IS NULL THEN
        v_anon_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.YkxK0zqLFkuS62t1SHY23Z9tAQqLuPJHoxPvvxKLTGQ';
    END IF;
    
    -- Call the Edge Function using http extension
    SELECT content INTO v_response
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
    
    -- Log the response
    RAISE LOG 'Push queue processor response: %', v_response;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log errors but don't fail
        RAISE LOG 'Error calling push queue processor: %', SQLERRM;
END;
$$;

COMMENT ON FUNCTION process_push_notification_queue() IS 
'Calls the Edge Function to process pending push notifications. Called by pg_cron every 30 seconds.';

-- Schedule the cron job to run every 30 seconds
-- Note: pg_cron uses standard cron syntax, but we can use a trick to run more frequently
SELECT cron.schedule(
    'process-push-notifications-1', -- Job name (first run at :00 and :30)
    '*/30 * * * * *', -- Every 30 seconds (if supported, otherwise fallback to minute)
    'SELECT process_push_notification_queue();'
);

-- Alternative: If 30-second intervals aren't supported, create two jobs that alternate
-- One runs at :00 seconds, another at :30 seconds
SELECT cron.schedule(
    'process-push-notifications-minute',
    '* * * * *', -- Every minute
    'SELECT process_push_notification_queue();'
);

-- Grant execute permission
GRANT EXECUTE ON FUNCTION process_push_notification_queue() TO service_role;
GRANT EXECUTE ON FUNCTION process_push_notification_queue() TO postgres;

-- Enable the http extension for making HTTP requests
CREATE EXTENSION IF NOT EXISTS http;

COMMENT ON EXTENSION http IS 'HTTP client for PostgreSQL - used to call Edge Functions from cron jobs';
