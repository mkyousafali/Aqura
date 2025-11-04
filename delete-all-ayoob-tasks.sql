-- STEP 1: Check how many tasks Ayoob has before deletion
SELECT 
    COUNT(*) as total_tasks_to_delete
FROM receiving_tasks rt
WHERE rt.assigned_user_id = '05e7f43b-2214-4056-a792-30f466ad7cc7';

-- STEP 2: See all task details before deletion (optional - for reference)
SELECT 
    rt.id as task_id,
    rt.role_type as task_role,
    rt.task_status,
    rt.title,
    rt.created_at
FROM receiving_tasks rt
WHERE rt.assigned_user_id = '05e7f43b-2214-4056-a792-30f466ad7cc7'
ORDER BY rt.created_at DESC
LIMIT 10;

-- STEP 3: DELETE ALL TASKS assigned to Ayoob using his UUID
DELETE FROM receiving_tasks 
WHERE assigned_user_id = '05e7f43b-2214-4056-a792-30f466ad7cc7';

-- STEP 4: Verify deletion worked - should return 0 tasks
SELECT 
    COUNT(*) as remaining_tasks_for_ayoob
FROM receiving_tasks rt
WHERE rt.assigned_user_id = '05e7f43b-2214-4056-a792-30f466ad7cc7';