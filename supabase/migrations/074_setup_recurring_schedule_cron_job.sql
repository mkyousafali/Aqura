-- Migration: Setup cron job to check recurring schedules daily
-- This requires pg_cron extension to be enabled

-- Enable pg_cron extension (if not already enabled)
-- Note: This may require superuser privileges or manual setup in Supabase dashboard
-- CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create a cron job to run the recurring schedule check daily at 6:00 AM
-- Note: Uncomment and run this after enabling pg_cron
/*
SELECT cron.schedule(
    'check-recurring-schedules-daily',
    '0 6 * * *',  -- Every day at 6:00 AM
    $$SELECT check_and_notify_recurring_schedules();$$
);
*/

-- Alternative: Create a table to track when the function was last run
CREATE TABLE IF NOT EXISTS recurring_schedule_check_log (
    id SERIAL PRIMARY KEY,
    check_date DATE NOT NULL DEFAULT CURRENT_DATE,
    schedules_checked INTEGER DEFAULT 0,
    notifications_sent INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(check_date)
);

-- Add RLS policy
ALTER TABLE recurring_schedule_check_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Only global users can view check logs"
    ON recurring_schedule_check_log
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
            AND users.user_type = 'global'
        )
    );

-- Create a wrapper function that logs execution
CREATE OR REPLACE FUNCTION check_and_notify_recurring_schedules_with_logging()
RETURNS TABLE (
    schedules_checked INTEGER,
    notifications_sent INTEGER,
    execution_date DATE,
    message TEXT
) AS $$
DECLARE
    checked_count INTEGER := 0;
    notified_count INTEGER := 0;
    rec RECORD;
BEGIN
    -- Run the notification check
    FOR rec IN SELECT * FROM check_and_notify_recurring_schedules()
    LOOP
        checked_count := checked_count + 1;
        IF rec.notification_sent THEN
            notified_count := notified_count + 1;
        END IF;
    END LOOP;
    
    -- Log the execution
    INSERT INTO recurring_schedule_check_log (
        check_date,
        schedules_checked,
        notifications_sent
    ) VALUES (
        CURRENT_DATE,
        checked_count,
        notified_count
    )
    ON CONFLICT (check_date) 
    DO UPDATE SET
        schedules_checked = recurring_schedule_check_log.schedules_checked + EXCLUDED.schedules_checked,
        notifications_sent = recurring_schedule_check_log.notifications_sent + EXCLUDED.notifications_sent;
    
    -- Return summary
    schedules_checked := checked_count;
    notifications_sent := notified_count;
    execution_date := CURRENT_DATE;
    message := FORMAT('Checked %s schedules, sent %s notifications', checked_count, notified_count);
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION check_and_notify_recurring_schedules_with_logging() TO authenticated;
GRANT EXECUTE ON FUNCTION check_and_notify_recurring_schedules_with_logging() TO service_role;

-- Add comment
COMMENT ON FUNCTION check_and_notify_recurring_schedules_with_logging() IS 
'Wrapper function that calls check_and_notify_recurring_schedules() and logs execution. Use this for cron jobs or manual execution.';

-- Instructions for manual execution (can be run from SQL editor):
COMMENT ON TABLE recurring_schedule_check_log IS 
'Log table for recurring schedule checks. 

To manually run the check, execute:
SELECT * FROM check_and_notify_recurring_schedules_with_logging();

To set up automatic daily execution:
1. Enable pg_cron extension in Supabase (may require contacting support)
2. Create cron job: 
   SELECT cron.schedule(''check-recurring-schedules'', ''0 6 * * *'', 
   $$SELECT check_and_notify_recurring_schedules_with_logging();$$);

Alternatively, use external cron service (GitHub Actions, Vercel Cron, etc.) to call:
POST https://your-project.supabase.co/rest/v1/rpc/check_and_notify_recurring_schedules_with_logging
';
