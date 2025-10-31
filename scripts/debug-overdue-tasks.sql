-- Debug Query: Find out why no overdue tasks are being found
-- Run this in Supabase SQL Editor

-- 1. Check total task_assignments with deadlines in the past
SELECT 
  'Total overdue assignments' as check_name,
  COUNT(*) as count
FROM task_assignments ta
WHERE COALESCE(ta.deadline_datetime, ta.deadline_date) < NOW();

-- 2. Check how many have completions
SELECT 
  'Overdue WITH completions' as check_name,
  COUNT(*) as count
FROM task_assignments ta
JOIN task_completions tc ON tc.assignment_id = ta.id
WHERE COALESCE(ta.deadline_datetime, ta.deadline_date) < NOW();

-- 3. Check how many are overdue WITHOUT completions
SELECT 
  'Overdue WITHOUT completions (should get reminders)' as check_name,
  COUNT(*) as count
FROM task_assignments ta
LEFT JOIN task_completions tc ON tc.assignment_id = ta.id
WHERE tc.id IS NULL
  AND COALESCE(ta.deadline_datetime, ta.deadline_date) < NOW();

-- 4. Check sample overdue tasks without completions
SELECT 
  ta.id as assignment_id,
  t.title as task_title,
  ta.assigned_to_user_id,
  u.username as user_name,
  COALESCE(ta.deadline_datetime, ta.deadline_date) as deadline,
  EXTRACT(EPOCH FROM (NOW() - COALESCE(ta.deadline_datetime, ta.deadline_date))) / 3600 as hours_overdue,
  tc.id as completion_id
FROM task_assignments ta
JOIN tasks t ON t.id = ta.task_id
JOIN users u ON u.id = ta.assigned_to_user_id
LEFT JOIN task_completions tc ON tc.assignment_id = ta.id
WHERE COALESCE(ta.deadline_datetime, ta.deadline_date) < NOW()
ORDER BY hours_overdue DESC
LIMIT 10;

-- 5. Check if there are NULL assigned_to_user_id
SELECT 
  'Tasks with NULL assigned_to_user_id' as check_name,
  COUNT(*) as count
FROM task_assignments ta
WHERE ta.assigned_to_user_id IS NULL
  AND COALESCE(ta.deadline_datetime, ta.deadline_date) < NOW();
