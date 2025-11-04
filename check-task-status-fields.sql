-- =====================================================
-- CHECK TASK STATUS FIELDS
-- =====================================================
-- Check what fields determine if a task shows as pending vs completed
-- =====================================================

-- Check the specific purchase manager task that was completed
SELECT 
    id,
    role_type,
    task_completed,
    assignment_status,
    completed_at,
    created_at
FROM receiving_tasks
WHERE role_type = 'purchase_manager'
    AND assigned_user_id = '807af948-0f5f-4f36-8925-747b152513c1'
ORDER BY created_at DESC
LIMIT 5;

-- Also check if there's a difference between task_completed and assignment_status
SELECT 
    COUNT(*) as total_tasks,
    COUNT(CASE WHEN task_completed = true THEN 1 END) as task_completed_true,
    COUNT(CASE WHEN assignment_status = 'completed' THEN 1 END) as assignment_status_completed,
    COUNT(CASE WHEN task_completed = true AND assignment_status != 'completed' THEN 1 END) as mismatch_count
FROM receiving_tasks
WHERE role_type = 'purchase_manager';