-- Manually trigger the automatic reminder function
-- This will send reminders for all 43 overdue tasks

SELECT * FROM check_overdue_tasks_and_send_reminders();

-- After running, check the results:
-- 1. Check reminder logs
SELECT COUNT(*) as reminders_sent FROM task_reminder_logs;

-- 2. Check notifications created
SELECT COUNT(*) as notifications_created 
FROM notifications 
WHERE type = 'task_overdue' 
AND created_by = 'system';

-- 3. View sample notifications
SELECT 
  title,
  message,
  target_users,
  target_type,
  status,
  created_by_name
FROM notifications
WHERE type = 'task_overdue'
AND created_by = 'system'
ORDER BY created_at DESC
LIMIT 5;
