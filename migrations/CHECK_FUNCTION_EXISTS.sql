-- Check if the automatic function exists
SELECT 
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines 
WHERE routine_name = 'check_overdue_tasks_and_send_reminders'
  AND routine_schema = 'public';

-- Check if cron job exists
SELECT 
  jobid,
  jobname,
  schedule,
  command,
  active,
  nodename
FROM cron.job 
WHERE jobname = 'check-overdue-tasks-reminders';

-- Try to execute the function manually to see if it exists
SELECT * FROM check_overdue_tasks_and_send_reminders();
