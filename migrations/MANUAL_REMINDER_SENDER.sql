-- ============================================================================
-- MANUAL OVERDUE TASK REMINDER SENDER
-- ============================================================================
-- Since automated function has RLS issues, use this manual script
-- Run this query whenever you want to send reminders for ALL overdue tasks
-- ============================================================================

-- Send reminders for overdue tasks
WITH overdue_tasks AS (
  SELECT 
    ta.id as assignment_id,
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
),
inserted_notifications AS (
  INSERT INTO public.notifications (title, message, type, target_users, target_type, status, sent_at, created_at, created_by, created_by_name, created_by_role, task_id, priority, read_count, total_recipients, metadata)
  SELECT 
    '⚠️ Overdue Task Reminder',
    'Task: "' || task_title || '" | Assigned to: ' || user_name || ' | Deadline: ' || TO_CHAR(deadline, 'YYYY-MM-DD HH24:MI') || ' | Overdue by: ' || ROUND(hours_overdue::NUMERIC, 1) || ' hours. Please complete it as soon as possible.',
    'task_overdue',
    jsonb_build_array(assigned_to_user_id::text),
    'specific_users',
    'published',
    NOW(),
    NOW(),
    'system',
    'System',
    'system',
    (SELECT task_id FROM public.task_assignments WHERE id = assignment_id),
    'medium',
    0,
    1,
    jsonb_build_object(
      'task_assignment_id', assignment_id,
      'task_title', task_title,
      'hours_overdue', ROUND(hours_overdue::NUMERIC, 1),
      'deadline', deadline,
      'reminder_type', 'manual'
    )
  FROM overdue_tasks
  RETURNING id, task_assignment_id as assignment_id
),
logged_reminders AS (
  INSERT INTO public.task_reminder_logs (task_assignment_id, task_title, assigned_to_user_id, deadline, hours_overdue, notification_id, status)
  SELECT 
    ot.assignment_id,
    ot.task_title,
    ot.assigned_to_user_id,
    ot.deadline,
    ROUND(ot.hours_overdue::NUMERIC, 1),
    inn.id,
    'sent'
  FROM overdue_tasks ot
  JOIN inserted_notifications inn ON inn.assignment_id = ot.assignment_id
  RETURNING *
)
SELECT 
  COUNT(*) as reminders_sent,
  string_agg(DISTINCT task_title, ', ') as tasks,
  string_agg(DISTINCT (SELECT username FROM users WHERE id = assigned_to_user_id), ', ') as users
FROM logged_reminders;

-- ============================================================================
-- RESULT: Shows how many reminders were sent and to which users
-- ============================================================================
