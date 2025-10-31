-- ============================================================================
-- DIAGNOSTIC QUERIES FOR REMINDER FUNCTION
-- ============================================================================
-- Run these queries one by one to diagnose why the function returns no rows

-- 1. Check if there are overdue tasks (should return 10+ rows)
SELECT 
  ta.id as assignment_id,
  t.title as task_title,
  ta.assigned_to_user_id,
  u.username as user_name,
  COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) as deadline,
  EXTRACT(EPOCH FROM (NOW() - COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime))) / 3600 as hours_overdue,
  tc.id as completion_id
FROM task_assignments ta
JOIN tasks t ON t.id = ta.task_id
JOIN users u ON u.id = ta.assigned_to_user_id
LEFT JOIN task_completions tc ON tc.assignment_id = ta.id
WHERE tc.id IS NULL  -- Not completed
  AND COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) IS NOT NULL  -- Has deadline
  AND COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) < NOW()  -- Overdue
ORDER BY hours_overdue DESC;

-- 2. Check if any reminders were already sent (should be empty first time)
SELECT * FROM task_reminder_logs ORDER BY reminder_sent_at DESC LIMIT 10;

-- 3. Check RLS policies on notifications table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE tablename = 'notifications';

-- 4. Try to manually insert a test notification as a test
DO $$
DECLARE
  test_user_id UUID;
  test_notification_id UUID;
BEGIN
  -- Get a test user
  SELECT id INTO test_user_id FROM users LIMIT 1;
  
  -- Try to insert
  INSERT INTO notifications (
    user_id,
    title,
    message,
    type,
    data,
    read,
    created_at
  ) VALUES (
    test_user_id,
    'Test Reminder',
    'This is a test',
    'task_overdue',
    '{"test": true}'::jsonb,
    false,
    NOW()
  ) RETURNING id INTO test_notification_id;
  
  RAISE NOTICE 'Successfully inserted test notification: %', test_notification_id;
  
  -- Clean up test
  DELETE FROM notifications WHERE id = test_notification_id;
  RAISE NOTICE 'Cleaned up test notification';
  
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Failed to insert test notification: %', SQLERRM;
END $$;

-- 5. Check if the function has proper permissions
SELECT 
  routine_name,
  routine_type,
  security_type,
  routine_definition
FROM information_schema.routines 
WHERE routine_name = 'check_overdue_tasks_and_send_reminders';
