-- STEP 1: Find Ayoob's mismatched receiving tasks
-- Run this first to see what tasks will be affected

SELECT 
    rt.id as task_id,
    rt.role_type as task_role,
    rt.task_status,
    rt.title,
    rt.created_at,
    u.username,
    u.role_type as user_role,
    'MISMATCH: ' || u.role_type::text || ' user assigned to ' || rt.role_type || ' task' as issue
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE u.username = 'ayoob'
    AND u.role_type::text != rt.role_type
    AND rt.task_status IN ('pending', 'in_progress')  -- Only active tasks
ORDER BY rt.created_at DESC;

-- STEP 2: Count how many mismatched tasks Ayoob has
SELECT 
    u.username,
    u.role_type as user_role,
    rt.role_type as task_role,
    rt.task_status,
    COUNT(*) as mismatch_count
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE u.username = 'ayoob'
    AND u.role_type::text != rt.role_type
    AND rt.task_status IN ('pending', 'in_progress')  -- Only active tasks
GROUP BY u.username, u.role_type, rt.role_type, rt.task_status;

-- STEP 3: Generate DELETE statement for Ayoob's mismatched tasks
-- Copy the result and run it to delete the mismatched tasks
SELECT 
    'DELETE FROM receiving_tasks WHERE id IN (' ||
    string_agg(rt.id::text, ', ') ||
    ');' as delete_statement
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE u.username = 'ayoob'
    AND u.role_type::text != rt.role_type
    AND rt.task_status IN ('pending', 'in_progress');  -- Only delete active tasks

-- STEP 4: Alternative - Delete specific role mismatches only
-- If you want to delete only inventory_manager tasks assigned to Ayoob:
/*
DELETE FROM receiving_tasks 
WHERE id IN (
    SELECT rt.id
    FROM receiving_tasks rt
    JOIN users u ON rt.assigned_user_id = u.id
    WHERE u.username = 'ayoob'
        AND rt.role_type = 'inventory_manager'
        AND u.role_type::text != rt.role_type
        AND rt.task_status IN ('pending', 'in_progress')
);
*/

-- STEP 5: Verify deletion worked
-- Run this after deletion to confirm no more mismatches for Ayoob
SELECT 
    COUNT(*) as remaining_mismatched_tasks
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE u.username = 'ayoob'
    AND u.role_type::text != rt.role_type
    AND rt.task_status IN ('pending', 'in_progress');