-- =====================================================
-- DEBUG BRANCH MANAGER TASK AND DEPENDENCIES
-- =====================================================
-- Check what branch manager task is trying to complete
-- and why it's not finding the shelf stocker photo
-- =====================================================

-- 1. Find the branch manager task details
SELECT 
    id,
    role_type,
    task_completed,
    receiving_record_id,
    assigned_user_id,
    created_at
FROM receiving_tasks 
WHERE id = '80c25bc2-08f2-4960-aa1e-5a45bc606e96';

-- 2. Show ALL tasks for the same receiving record as the branch manager
SELECT 
    id,
    role_type,
    task_completed,
    completion_photo_url IS NOT NULL as has_photo,
    completion_photo_url,
    completed_at,
    receiving_record_id
FROM receiving_tasks 
WHERE receiving_record_id = (
    SELECT receiving_record_id 
    FROM receiving_tasks 
    WHERE id = '80c25bc2-08f2-4960-aa1e-5a45bc606e96'
)
ORDER BY role_type;

-- 3. Test our function with the branch manager's receiving_record_id
SELECT get_dependency_completion_photos(
    (SELECT receiving_record_id FROM receiving_tasks WHERE id = '80c25bc2-08f2-4960-aa1e-5a45bc606e96'),
    ARRAY['shelf_stocker']
) as photos_for_branch_manager;

-- 4. Check what receiving_task_templates says about branch_manager dependencies
SELECT 
    role_type,
    depends_on_role_types,
    require_photo_upload
FROM receiving_task_templates 
WHERE role_type = 'branch_manager';

-- 5. Run the dependency check function for the branch manager
SELECT check_receiving_task_dependencies(
    (SELECT receiving_record_id FROM receiving_tasks WHERE id = '80c25bc2-08f2-4960-aa1e-5a45bc606e96'),
    'branch_manager'
) as dependency_status;