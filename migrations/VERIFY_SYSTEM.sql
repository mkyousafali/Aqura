-- ============================================================================
-- VERIFY AUTOMATIC SYSTEM IS WORKING
-- ============================================================================

-- 1. Check if function exists with correct definition
SELECT 
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines 
WHERE routine_name = 'check_overdue_tasks_and_send_reminders'
  AND routine_schema = 'public';

-- 2. Check if cron job is active
SELECT 
  jobid,
  jobname,
  schedule,
  command,
  active
FROM cron.job 
WHERE jobname = 'check-overdue-tasks-reminders';

-- 3. Check how many overdue tasks exist
SELECT 
  COUNT(*) as total_overdue_tasks,
  COUNT(CASE WHEN EXISTS (
    SELECT 1 FROM task_reminder_logs trl WHERE trl.task_assignment_id = ta.id
  ) THEN 1 END) as already_have_reminders,
  COUNT(CASE WHEN NOT EXISTS (
    SELECT 1 FROM task_reminder_logs trl WHERE trl.task_assignment_id = ta.id
  ) THEN 1 END) as need_reminders
FROM task_assignments ta
JOIN tasks t ON t.id = ta.task_id
LEFT JOIN task_completions tc ON tc.assignment_id = ta.id
WHERE tc.id IS NULL
  AND COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) IS NOT NULL
  AND COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) < NOW();

-- 4. View recent reminder logs
SELECT 
  task_title,
  (SELECT username FROM users WHERE id = assigned_to_user_id) as user_name,
  hours_overdue,
  status,
  reminder_sent_at,
  created_at
FROM task_reminder_logs
ORDER BY created_at DESC
LIMIT 10;

-- 5. Check recent task_overdue notifications
SELECT 
  title,
  LEFT(message, 100) as message_preview,
  target_type,
  status,
  created_by_name,
  sent_at,
  created_at
FROM notifications
WHERE type = 'task_overdue'
ORDER BY created_at DESC
LIMIT 10;
