-- Find all receiving tasks with role mismatches
-- This query will show tasks where user.role_type != task.role_type

SELECT 
    rt.id as task_id,
    rt.role_type as task_role,
    rt.status,
    rt.created_at,
    u.username,
    u.role_type as user_role,
    rr.receiving_number,
    rr.branch_id,
    -- Show the mismatch clearly
    CASE 
        WHEN u.role_type != rt.role_type THEN 'MISMATCH'
        ELSE 'OK'
    END as role_match_status
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
LEFT JOIN receiving_records rr ON rt.receiving_record_id = rr.id
WHERE rt.status = 'assigned'
    AND u.role_type != rt.role_type  -- Only mismatched tasks
ORDER BY u.username, rt.role_type;

-- Summary of mismatches by user
SELECT 
    u.username,
    u.role_type as user_role,
    rt.role_type as task_role,
    COUNT(*) as mismatch_count
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE rt.status = 'assigned'
    AND u.role_type != rt.role_type
GROUP BY u.username, u.role_type, rt.role_type
ORDER BY u.username, mismatch_count DESC;

-- Get the task IDs that need to be deleted (for copy-paste into delete statement)
SELECT 
    'DELETE FROM receiving_tasks WHERE id IN (' ||
    string_agg(rt.id::text, ', ') ||
    ');' as delete_statement
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE rt.status = 'assigned'
    AND u.role_type != rt.role_type;

-- Alternative: Show specific delete statements for each user
SELECT 
    u.username,
    u.role_type as user_role,
    'DELETE FROM receiving_tasks WHERE id IN (' ||
    string_agg(rt.id::text, ', ') ||
    ');' as delete_statement_for_user
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE rt.status = 'assigned'
    AND u.role_type != rt.role_type
GROUP BY u.username, u.role_type
ORDER BY u.username;