-- ============================================================================
-- FIX AUTOMATIC REMINDER FUNCTION - FINAL VERSION
-- ============================================================================
-- This fixes the function to work with cron by using SECURITY DEFINER
-- and proper schema qualification
-- ============================================================================

-- Drop the old function
DROP FUNCTION IF EXISTS check_overdue_tasks_and_send_reminders();

-- Create function with SECURITY DEFINER to bypass RLS
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
SECURITY DEFINER  -- Run with function owner's permissions
SET search_path = public  -- Explicitly set schema
AS $$
DECLARE
  task_record RECORD;
  notification_id UUID;
  reminder_count INTEGER := 0;
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
    FROM task_assignments ta
    JOIN tasks t ON t.id = ta.task_id
    JOIN users u ON u.id = ta.assigned_to_user_id
    LEFT JOIN task_completions tc ON tc.assignment_id = ta.id
    WHERE tc.id IS NULL  -- Not completed
      AND COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) IS NOT NULL  -- Has deadline
      AND COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) < NOW()  -- Overdue
      AND NOT EXISTS (  -- No reminder sent yet
        SELECT 1 FROM task_reminder_logs trl 
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
        task_record.task_id,
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
        task_record.task_id,
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
  RETURN;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION check_overdue_tasks_and_send_reminders() TO postgres;
GRANT EXECUTE ON FUNCTION check_overdue_tasks_and_send_reminders() TO authenticated;
GRANT EXECUTE ON FUNCTION check_overdue_tasks_and_send_reminders() TO service_role;

-- Add comment
COMMENT ON FUNCTION check_overdue_tasks_and_send_reminders() IS 'Automatic task reminder system - runs hourly via pg_cron. Uses SECURITY DEFINER to bypass RLS.';

-- ============================================================================
-- TEST THE FUNCTION
-- ============================================================================
SELECT * FROM check_overdue_tasks_and_send_reminders();

-- Check results
SELECT COUNT(*) as reminders_sent FROM task_reminder_logs WHERE created_at > NOW() - INTERVAL '1 minute';
SELECT COUNT(*) as notifications_created FROM notifications WHERE type = 'task_overdue' AND created_at > NOW() - INTERVAL '1 minute';
