-- =====================================================
-- DEBUG DEPENDENCY PHOTOS ISSUE
-- =====================================================
-- Check what's actually in the database for dependency photos
-- =====================================================

-- First, let's see what's in the receiving_tasks table for this specific receiving_record_id
-- Replace the UUID below with the actual receiving_record_id from the logs: 64dae86d-efc8-423f-ada2-0cebb0f46490

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

-- Now let's test our function with the actual receiving_record_id
SELECT get_dependency_completion_photos(
    '64dae86d-efc8-423f-ada2-0cebb0f46490'::UUID,
    ARRAY['shelf_stocker']
) as actual_photos;

-- Let's also check if shelf_stocker task exists and has photo
SELECT 
    id,
    role_type,
    task_completed,
    completion_photo_url IS NOT NULL as has_photo,
    completion_photo_url
FROM receiving_tasks 
WHERE receiving_record_id = '64dae86d-efc8-423f-ada2-0cebb0f46490'
    AND role_type = 'shelf_stocker'
    AND task_completed = true;

-- Debug: Check if the column exists and has data
SELECT 
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_name = 'receiving_tasks' 
    AND column_name = 'completion_photo_url';

-- Check if there are ANY tasks with completion photos
SELECT 
    COUNT(*) as total_tasks,
    COUNT(completion_photo_url) as tasks_with_photos
FROM receiving_tasks;