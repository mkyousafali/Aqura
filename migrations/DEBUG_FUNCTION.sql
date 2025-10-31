-- ============================================================================
-- DEBUG AUTOMATIC FUNCTION
-- ============================================================================

-- 1. Check if function exists and get its details
SELECT 
  routine_name,
  routine_type,
  security_type,
  routine_definition
FROM information_schema.routines 
WHERE routine_name = 'check_overdue_tasks_and_send_reminders'
  AND routine_schema = 'public';

-- 2. Check current overdue tasks that should get reminders
SELECT 
  ta.id as assignment_id,
  t.id as task_id,
  t.title as task_title,
  ta.assigned_to_user_id,
  u.username as user_name,
  COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) as deadline,
  EXTRACT(EPOCH FROM (NOW() - COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime))) / 3600 as hours_overdue,
  EXISTS (SELECT 1 FROM task_reminder_logs trl WHERE trl.task_assignment_id = ta.id) as reminder_already_sent,
  EXISTS (SELECT 1 FROM task_completions tc WHERE tc.assignment_id = ta.id) as is_completed
FROM task_assignments ta
JOIN tasks t ON t.id = ta.task_id
JOIN users u ON u.id = ta.assigned_to_user_id
WHERE COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) IS NOT NULL
  AND COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) < NOW()
ORDER BY hours_overdue DESC;

-- 3. Try to execute the function manually with debug output
SELECT * FROM check_overdue_tasks_and_send_reminders();

-- 4. Check if any errors occurred
SELECT * FROM pg_stat_statements 
WHERE query LIKE '%check_overdue_tasks_and_send_reminders%' 
ORDER BY calls DESC 
LIMIT 5;
