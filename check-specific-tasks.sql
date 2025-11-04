-- =====================================================
-- CHECK SPECIFIC RECEIVING RECORD TASKS
-- =====================================================
-- Let's see the tasks for this specific receiving record
-- =====================================================

-- 1. Show all tasks for this receiving record
SELECT 
    id,
    role_type,
    task_completed,
    completion_photo_url,
    completed_at,
    assigned_user_id
FROM receiving_tasks 
WHERE receiving_record_id = '64dae86d-efc8-423f-ada2-0cebb0f46490'
ORDER BY role_type;

-- 2. Check if completion_photo_url column exists
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'receiving_tasks' 
    AND column_name = 'completion_photo_url';

-- 3. Find the shelf_stocker task specifically
SELECT 
    id,
    role_type,
    task_completed,
    completion_photo_url,
    completed_at
FROM receiving_tasks 
WHERE receiving_record_id = '64dae86d-efc8-423f-ada2-0cebb0f46490'
    AND role_type = 'shelf_stocker';