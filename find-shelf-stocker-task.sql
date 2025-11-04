-- =====================================================
-- FIND THE ACTUAL SHELF STOCKER TASK
-- =====================================================
-- Let's find exactly what shelf stocker tasks exist
-- =====================================================

-- 1. Find ALL shelf stocker tasks for this receiving record (remove filters)
SELECT 
    id,
    role_type,
    task_completed,
    completion_photo_url,
    completion_photo_url IS NOT NULL as has_photo_url,
    completed_at,
    receiving_record_id
FROM receiving_tasks
WHERE receiving_record_id = '64dae86d-efc8-423f-ada2-0cebb0f46490'
    AND role_type = 'shelf_stocker';

-- 2. Find ALL tasks with photos for this receiving record
SELECT 
    id,
    role_type,
    task_completed,
    completion_photo_url,
    completed_at,
    receiving_record_id
FROM receiving_tasks
WHERE receiving_record_id = '64dae86d-efc8-423f-ada2-0cebb0f46490'
    AND completion_photo_url IS NOT NULL;

-- 3. Find the specific task we saw earlier that had a photo
SELECT 
    id,
    role_type,
    task_completed,
    completion_photo_url,
    completed_at,
    receiving_record_id
FROM receiving_tasks
WHERE id = '7ccc4a84-e6cf-4218-a7bc-8c1ba44dfe75';

-- 4. Check if that task is for the same receiving record as the branch manager
SELECT 
    'Branch Manager' as task_type,
    id,
    receiving_record_id
FROM receiving_tasks
WHERE id = '80c25bc2-08f2-4960-aa1e-5a45bc606e96'
UNION ALL
SELECT 
    'Shelf Stocker' as task_type,
    id,
    receiving_record_id
FROM receiving_tasks
WHERE id = '7ccc4a84-e6cf-4218-a7bc-8c1ba44dfe75';