-- ============================================================================
-- AUTOMATIC TASK REMINDER SYSTEM
-- ============================================================================
-- This migration sets up an automatic reminder system for overdue tasks
-- Created: 2025-10-31
-- ============================================================================

-- Step 1: Create task_reminder_logs table
-- ============================================================================
CREATE TABLE IF NOT EXISTS task_reminder_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_assignment_id UUID REFERENCES task_assignments(id) ON DELETE CASCADE,
  quick_task_assignment_id UUID REFERENCES quick_task_assignments(id) ON DELETE CASCADE,
  task_title TEXT NOT NULL,
  assigned_to_user_id UUID REFERENCES users(id),
  deadline TIMESTAMPTZ NOT NULL,
  hours_overdue NUMERIC,
  reminder_sent_at TIMESTAMPTZ DEFAULT NOW(),
  notification_id UUID REFERENCES notifications(id),
  status TEXT DEFAULT 'sent',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure only one of task_assignment_id or quick_task_assignment_id is set
  CONSTRAINT check_single_assignment CHECK (
    (task_assignment_id IS NOT NULL AND quick_task_assignment_id IS NULL) OR
    (task_assignment_id IS NULL AND quick_task_assignment_id IS NOT NULL)
  )
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_task_reminder_logs_task_assignment 
ON task_reminder_logs(task_assignment_id) WHERE task_assignment_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_task_reminder_logs_quick_task 
ON task_reminder_logs(quick_task_assignment_id) WHERE quick_task_assignment_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_task_reminder_logs_user 
ON task_reminder_logs(assigned_to_user_id);

CREATE INDEX IF NOT EXISTS idx_task_reminder_logs_sent_at 
ON task_reminder_logs(reminder_sent_at);

CREATE INDEX IF NOT EXISTS idx_task_reminder_logs_status 
ON task_reminder_logs(status);

-- Enable Row Level Security
ALTER TABLE task_reminder_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own reminder logs" ON task_reminder_logs;
DROP POLICY IF EXISTS "Admins can view all reminder logs" ON task_reminder_logs;
DROP POLICY IF EXISTS "Authenticated users can view all reminder logs" ON task_reminder_logs;
DROP POLICY IF EXISTS "Service role can insert reminder logs" ON task_reminder_logs;

-- Policy: Users can view their own reminder logs
CREATE POLICY "Users can view their own reminder logs"
ON task_reminder_logs FOR SELECT
USING (assigned_to_user_id = auth.uid());

-- Policy: All authenticated users can view all reminder logs  
-- (Since admin/master_admin is determined by another field, not user_type)
CREATE POLICY "Authenticated users can view all reminder logs"
ON task_reminder_logs FOR SELECT
USING (auth.uid() IS NOT NULL);

-- Policy: Service role can insert reminder logs
CREATE POLICY "Service role can insert reminder logs"
ON task_reminder_logs FOR INSERT
WITH CHECK (true);

-- Add comment to table
COMMENT ON TABLE task_reminder_logs IS 'Logs all automatic and manual task reminders sent to users';

-- ============================================================================
-- Step 2: Create function to check and send reminders
-- ============================================================================
CREATE OR REPLACE FUNCTION check_overdue_tasks_and_send_reminders()
RETURNS TABLE (
  task_id UUID,
  task_title TEXT,
  user_id UUID,
  user_name TEXT,
  hours_overdue NUMERIC,
  reminder_sent BOOLEAN
) 
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  task_record RECORD;
  notification_id UUID;
  reminder_count INTEGER := 0;
  overdue_tasks_list TEXT;
BEGIN
  RAISE NOTICE 'Starting overdue task reminder check at %', NOW();

  -- ========================================
  -- Check regular task assignments
  -- ========================================
  FOR task_record IN
    SELECT 
      ta.id as assignment_id,
      t.id as task_id,
      t.title as task_title,
      ta.assigned_to_user_id,
      u.username as user_name,
      COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) as deadline,
      EXTRACT(EPOCH FROM (NOW() - COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime))) / 3600 as hours_overdue
    FROM public.task_assignments ta
    JOIN public.tasks t ON t.id = ta.task_id
    JOIN public.users u ON u.id = ta.assigned_to_user_id
    LEFT JOIN public.task_completions tc ON tc.assignment_id = ta.id
    WHERE tc.id IS NULL  -- Not completed
      AND COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) IS NOT NULL  -- Has deadline
      AND COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) < NOW()  -- Overdue
      AND NOT EXISTS (  -- No reminder sent yet
        SELECT 1 FROM public.task_reminder_logs trl 
        WHERE trl.task_assignment_id = ta.id
      )
    ORDER BY hours_overdue DESC
  LOOP
    BEGIN
      -- Insert notification
      INSERT INTO notifications (
        title,
        message,
        type,
        target_users,
        target_type,
        status,
        sent_at,
        created_at,
        created_by,
        created_by_name,
        created_by_role,
        task_id,
        priority,
        read_count,
        total_recipients,
        metadata
      ) VALUES (
        '⚠️ Overdue Task Reminder',
        'Task: "' || task_record.task_title || '" | Assigned to: ' || task_record.user_name || ' | Deadline: ' || TO_CHAR(task_record.deadline, 'YYYY-MM-DD HH24:MI') || ' | Overdue by: ' || ROUND(task_record.hours_overdue::NUMERIC, 1) || ' hours. Please complete it as soon as possible.',
        'task_overdue',
        jsonb_build_array(task_record.assigned_to_user_id::text),
        'specific_users',
        'published',
        NOW(),
        NOW(),
        'system',
        'System',
        'system',
        task_record.task_id,
        'medium',
        0,
        1,
        jsonb_build_object(
          'task_assignment_id', task_record.assignment_id,
          'task_title', task_record.task_title,
          'hours_overdue', ROUND(task_record.hours_overdue::NUMERIC, 1),
          'deadline', task_record.deadline,
          'reminder_type', 'automatic'
        )
      ) RETURNING id INTO notification_id;

      -- Log the reminder
      INSERT INTO task_reminder_logs (
        task_assignment_id,
        task_title,
        assigned_to_user_id,
        deadline,
        hours_overdue,
        notification_id,
        status
      ) VALUES (
        task_record.assignment_id,
        task_record.task_title,
        task_record.assigned_to_user_id,
        task_record.deadline,
        ROUND(task_record.hours_overdue::NUMERIC, 1),
        notification_id,
        'sent'
      );

      reminder_count := reminder_count + 1;

      -- Return the result
      RETURN QUERY SELECT 
        task_record.assignment_id,
        task_record.task_title,
        task_record.assigned_to_user_id,
        task_record.user_name,
        ROUND(task_record.hours_overdue::NUMERIC, 1),
        TRUE;

      RAISE NOTICE 'Sent reminder for task "%" to user "%"', task_record.task_title, task_record.user_name;

    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to send reminder for task %: %', task_record.assignment_id, SQLERRM;
      CONTINUE;
    END;
  END LOOP;

  -- ========================================
  -- Check quick task assignments
  -- ========================================
  FOR task_record IN
    SELECT 
      qa.id as assignment_id,
      qt.id as task_id,
      qt.title as task_title,
      qa.assigned_to_user_id,
      u.username as user_name,
      qt.deadline_datetime as deadline,
      EXTRACT(EPOCH FROM (NOW() - qt.deadline_datetime)) / 3600 as hours_overdue
    FROM quick_task_assignments qa
    JOIN quick_tasks qt ON qt.id = qa.quick_task_id
    JOIN users u ON u.id = qa.assigned_to_user_id
    LEFT JOIN quick_task_completions qc ON qc.assignment_id = qa.id
    WHERE qc.id IS NULL  -- Not completed
      AND qt.deadline_datetime < NOW()  -- Overdue
      AND NOT EXISTS (  -- No reminder sent yet
        SELECT 1 FROM task_reminder_logs trl 
        WHERE trl.quick_task_assignment_id = qa.id
      )
    ORDER BY hours_overdue DESC
  LOOP
    BEGIN
      -- Insert notification
      INSERT INTO notifications (
        title,
        message,
        type,
        target_users,
        target_type,
        status,
        sent_at,
        created_at,
        created_by,
        created_by_name,
        created_by_role,
        task_id,
        priority,
        read_count,
        total_recipients,
        metadata
      ) VALUES (
        '⚠️ Overdue Quick Task Reminder',
        'Quick Task: "' || task_record.task_title || '" | Assigned to: ' || task_record.user_name || ' | Deadline: ' || TO_CHAR(task_record.deadline, 'YYYY-MM-DD HH24:MI') || ' | Overdue by: ' || ROUND(task_record.hours_overdue::NUMERIC, 1) || ' hours. Please complete it as soon as possible.',
        'task_overdue',
        jsonb_build_array(task_record.assigned_to_user_id::text),
        'specific_users',
        'published',
        NOW(),
        NOW(),
        'system',
        'System',
        'system',
        task_record.task_id,
        'medium',
        0,
        1,
        jsonb_build_object(
          'quick_task_assignment_id', task_record.assignment_id,
          'task_title', task_record.task_title,
          'hours_overdue', ROUND(task_record.hours_overdue::NUMERIC, 1),
          'deadline', task_record.deadline,
          'reminder_type', 'automatic'
        )
      ) RETURNING id INTO notification_id;

      -- Log the reminder
      INSERT INTO task_reminder_logs (
        quick_task_assignment_id,
        task_title,
        assigned_to_user_id,
        deadline,
        hours_overdue,
        notification_id,
        status
      ) VALUES (
        task_record.assignment_id,
        task_record.task_title,
        task_record.assigned_to_user_id,
        task_record.deadline,
        ROUND(task_record.hours_overdue::NUMERIC, 1),
        notification_id,
        'sent'
      );

      reminder_count := reminder_count + 1;

      -- Return the result
      RETURN QUERY SELECT 
        task_record.assignment_id,
        task_record.task_title,
        task_record.assigned_to_user_id,
        task_record.user_name,
        ROUND(task_record.hours_overdue::NUMERIC, 1),
        TRUE;

      RAISE NOTICE 'Sent reminder for quick task "%" to user "%"', task_record.task_title, task_record.user_name;

    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to send reminder for quick task %: %', task_record.assignment_id, SQLERRM;
      CONTINUE;
    END;
  END LOOP;

  RAISE NOTICE 'Completed overdue task reminder check. Sent % reminders.', reminder_count;
END;
$$;

-- Add comment to function
COMMENT ON FUNCTION check_overdue_tasks_and_send_reminders() IS 'Checks for overdue tasks and sends automatic reminders via notifications. Returns list of tasks that were sent reminders.';

-- ============================================================================
-- Step 3: Create function to get reminder statistics
-- ============================================================================
CREATE OR REPLACE FUNCTION get_reminder_statistics(
  p_user_id UUID DEFAULT NULL,
  p_days INTEGER DEFAULT 30
)
RETURNS TABLE (
  total_reminders BIGINT,
  reminders_today BIGINT,
  reminders_this_week BIGINT,
  reminders_this_month BIGINT,
  avg_hours_overdue NUMERIC,
  most_overdue_task TEXT
) AS $$
BEGIN
  RETURN QUERY
  WITH stats AS (
    SELECT
      COUNT(*) as total,
      COUNT(*) FILTER (WHERE DATE(reminder_sent_at) = CURRENT_DATE) as today,
      COUNT(*) FILTER (WHERE reminder_sent_at >= CURRENT_DATE - INTERVAL '7 days') as week,
      COUNT(*) FILTER (WHERE reminder_sent_at >= CURRENT_DATE - INTERVAL '30 days') as month,
      AVG(hours_overdue) as avg_overdue
    FROM task_reminder_logs
    WHERE (p_user_id IS NULL OR assigned_to_user_id = p_user_id)
      AND reminder_sent_at >= CURRENT_DATE - (p_days || ' days')::INTERVAL
  ),
  most_overdue AS (
    SELECT task_title
    FROM task_reminder_logs
    WHERE (p_user_id IS NULL OR assigned_to_user_id = p_user_id)
    ORDER BY hours_overdue DESC NULLS LAST
    LIMIT 1
  )
  SELECT 
    COALESCE(s.total, 0),
    COALESCE(s.today, 0),
    COALESCE(s.week, 0),
    COALESCE(s.month, 0),
    ROUND(COALESCE(s.avg_overdue, 0), 1),
    COALESCE(m.task_title, 'N/A')
  FROM stats s
  CROSS JOIN most_overdue m;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_reminder_statistics(UUID, INTEGER) IS 'Returns statistics about sent reminders for a user or all users';

-- ============================================================================
-- Step 4: Setup Cron Job (pg_cron extension)
-- ============================================================================
-- Note: pg_cron extension must be enabled in Supabase dashboard first
-- Go to: Database → Extensions → Enable pg_cron

-- Enable pg_cron extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Remove existing job if it exists (with error handling)
DO $$
BEGIN
  PERFORM cron.unschedule('check-overdue-tasks-reminders');
  RAISE NOTICE 'Unscheduled existing job';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'No existing job to unschedule (this is fine for first run)';
END $$;

-- Schedule the reminder check to run every hour
SELECT cron.schedule(
  'check-overdue-tasks-reminders',
  '0 * * * *',  -- Every hour at minute 0 (cron format: minute hour day month weekday)
  $$SELECT check_overdue_tasks_and_send_reminders();$$
);

-- ============================================================================
-- Step 5: Grant necessary permissions
-- ============================================================================
-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION check_overdue_tasks_and_send_reminders() TO authenticated;
GRANT EXECUTE ON FUNCTION get_reminder_statistics(UUID, INTEGER) TO authenticated;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these queries to verify the setup:

-- 1. Check if table was created
-- SELECT * FROM pg_tables WHERE tablename = 'task_reminder_logs';

-- 2. Check if function exists
-- SELECT routine_name FROM information_schema.routines 
-- WHERE routine_name = 'check_overdue_tasks_and_send_reminders';

-- 3. Check if cron job is scheduled
-- SELECT * FROM cron.job WHERE jobname = 'check-overdue-tasks-reminders';

-- 4. Manually test the function
-- SELECT * FROM check_overdue_tasks_and_send_reminders();

-- 5. Check reminder statistics
-- SELECT * FROM get_reminder_statistics();

-- 6. View recent reminders
-- SELECT * FROM task_reminder_logs ORDER BY reminder_sent_at DESC LIMIT 10;

-- ============================================================================
-- SUCCESS! 
-- ============================================================================
-- The automatic task reminder system is now set up and will:
-- 1. Check for overdue tasks every hour
-- 2. Send notifications to users with overdue tasks (once per task)
-- 3. Log all reminders in task_reminder_logs table
-- 4. Provide statistics via get_reminder_statistics() function
--
-- You can manually trigger the reminder check at any time by running:
--   SELECT * FROM check_overdue_tasks_and_send_reminders();
-- ============================================================================
