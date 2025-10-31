-- ============================================================================
-- DEPLOY AUTOMATIC REMINDER SYSTEM
-- ============================================================================
-- Run this entire script in Supabase SQL Editor to set up the automatic system
-- ============================================================================

-- Step 1: Drop existing function if it exists (to update it)
DROP FUNCTION IF EXISTS check_overdue_tasks_and_send_reminders();

-- Step 2: Drop existing cron job if it exists
DO $$
BEGIN
  PERFORM cron.unschedule('check-overdue-tasks-reminders');
EXCEPTION
  WHEN OTHERS THEN
    NULL; -- Ignore if job doesn't exist
END $$;

-- Step 3: Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Step 4: Now run the complete setup-automatic-task-reminders.sql file
-- Copy and paste the entire content of setup-automatic-task-reminders.sql here

\echo 'Please run the complete setup-automatic-task-reminders.sql file now'
\echo 'Then come back and run CHECK_FUNCTION_EXISTS.sql to verify'
