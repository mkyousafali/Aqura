-- Script to find and display tasks with NULL branch_id to understand their source
-- This will help us identify how to properly assign branches

SELECT 
    ta.id as assignment_id,
    t.id as task_id,
    t.title,
    LEFT(t.description, 100) as description_start,
    ta.assigned_to_user_id,
    ta.assigned_by,
    ta.assignment_type,
    ta.assigned_at,
    t.created_by,
    t.created_at
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
WHERE ta.assigned_to_branch_id IS NULL
ORDER BY ta.assigned_at DESC
LIMIT 20;
