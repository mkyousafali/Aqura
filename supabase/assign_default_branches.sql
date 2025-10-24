-- Script to assign remaining NULL branch_ids to default branch
-- This handles tasks not created through receiving process

BEGIN;

-- Get the most common branch_id from existing task_assignments
-- and use it as default for NULL values
WITH most_common_branch AS (
    SELECT assigned_to_branch_id, COUNT(*) as count
    FROM task_assignments
    WHERE assigned_to_branch_id IS NOT NULL
    GROUP BY assigned_to_branch_id
    ORDER BY count DESC
    LIMIT 1
)
UPDATE public.task_assignments ta
SET assigned_to_branch_id = (SELECT assigned_to_branch_id FROM most_common_branch)
WHERE ta.assigned_to_branch_id IS NULL;

-- Show results
SELECT 
    COUNT(*) as total_tasks,
    COUNT(assigned_to_branch_id) as with_branch,
    COUNT(*) - COUNT(assigned_to_branch_id) as still_null
FROM task_assignments;

COMMIT;
