-- ============================================================================
-- TEST AUTOMATIC REMINDER SYSTEM
-- ============================================================================
-- This will test if the automatic reminder function is working

-- 1. Check if the cron job is scheduled
SELECT 
  jobid,
  jobname,
  schedule,
  command,
  active
FROM cron.job 
WHERE jobname = 'check-overdue-tasks-reminders';

-- 2. Manually trigger the automatic function to test it
SELECT * FROM check_overdue_tasks_and_send_reminders();

-- 3. Check if reminders were logged
SELECT 
  COUNT(*) as total_reminders,
  COUNT(DISTINCT task_assignment_id) as unique_tasks,
  COUNT(DISTINCT assigned_to_user_id) as unique_users
FROM task_reminder_logs;

-- 4. View recent reminder details
SELECT 
  task_title,
  (SELECT username FROM users WHERE id = assigned_to_user_id) as assigned_to,
  deadline,
  hours_overdue,
  status,
  created_at
FROM task_reminder_logs
ORDER BY created_at DESC
LIMIT 10;

-- 5. Check if notifications were created
SELECT 
  title,
  message,
  type,
  target_users,
  target_type,
  status,
  created_by_name,
  created_at
FROM notifications
WHERE type = 'task_overdue'
ORDER BY created_at DESC
LIMIT 10;
