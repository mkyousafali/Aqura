-- Check ALL tasks assigned to Ayoob (not just pending/in_progress)
SELECT 
    rt.id as task_id,
    rt.role_type as task_role,
    rt.task_status,
    rt.title,
    rt.created_at,
    u.username,
    u.role_type as user_role,
    CASE 
        WHEN u.role_type::text != rt.role_type THEN 'MISMATCH ❌'
        ELSE 'OK ✅'
    END as status
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE u.username = 'ayoob'
ORDER BY rt.created_at DESC
LIMIT 20;

-- Count tasks by status
SELECT 
    rt.task_status,
    rt.role_type,
    COUNT(*) as task_count,
    CASE 
        WHEN u.role_type::text != rt.role_type THEN 'MISMATCH ❌'
        ELSE 'OK ✅'
    END as status
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE u.username = 'ayoob'
GROUP BY rt.task_status, rt.role_type, u.role_type
ORDER BY rt.task_status, rt.role_type;

-- Check the specific failing task from the console log
SELECT 
    rt.id as task_id,
    rt.role_type as task_role,
    rt.task_status,
    rt.title,
    rt.created_at,
    u.username,
    u.role_type as user_role,
    CASE 
        WHEN u.role_type::text != rt.role_type THEN 'MISMATCH ❌'
        ELSE 'OK ✅'
    END as status
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE rt.id = '12dfe564-9720-45b6-8c0b-83011ae24888';

-- Get Ayoob's user info to verify
SELECT id, username, role_type FROM users WHERE username = 'ayoob';

-- Check if there are ANY inventory_manager tasks assigned to Ayoob
SELECT 
    rt.id,
    rt.role_type,
    rt.task_status,
    rt.title,
    u.username,
    u.role_type as user_role
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE u.username = 'ayoob'
    AND rt.role_type = 'inventory_manager'
ORDER BY rt.created_at DESC;

-- Generate DELETE statement for ALL mismatched tasks (regardless of status)
SELECT 
    'DELETE FROM receiving_tasks WHERE id IN (' ||
    string_agg(rt.id::text, ', ') ||
    ');' as delete_all_mismatched_statement
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE u.username = 'ayoob'
    AND u.role_type::text != rt.role_type;

-- Alternative: Check for any tasks that might cause role validation error
SELECT 
    rt.id,
    rt.role_type,
    rt.task_status,
    u.username,
    u.role_type as user_role,
    'User role: ' || u.role_type::text || ' vs Task role: ' || rt.role_type as comparison
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE u.username = 'ayoob'
    AND (u.role_type::text != rt.role_type OR rt.role_type = 'inventory_manager');