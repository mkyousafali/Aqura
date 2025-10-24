-- Script to update all NULL branch_ids in task_assignments
-- Run this directly in your database

BEGIN;

-- Update all NULL branch_ids to the first available branch
UPDATE public.task_assignments
SET assigned_to_branch_id = (
    SELECT id FROM branches ORDER BY id LIMIT 1
)
WHERE assigned_to_branch_id IS NULL;

-- Verify the update
SELECT 
    COUNT(*) as total_assignments,
    COUNT(assigned_to_branch_id) as with_branch,
    COUNT(*) - COUNT(assigned_to_branch_id) as without_branch
FROM task_assignments;

COMMIT;
