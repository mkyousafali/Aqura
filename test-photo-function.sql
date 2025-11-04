-- =====================================================
-- SIMPLE TEST OF PHOTO FUNCTION
-- =====================================================
-- Test with the known good shelf stocker data
-- =====================================================

-- Test with the receiving record we know has a shelf stocker with photo
SELECT get_dependency_completion_photos(
    '64dae86d-efc8-423f-ada2-0cebb0f46490'::UUID,
    ARRAY['shelf_stocker']
) as test_result;

-- Let's also manually run the logic from inside our function
SELECT 
    role_type,
    completion_photo_url,
    task_completed
FROM receiving_tasks
WHERE receiving_record_id = '64dae86d-efc8-423f-ada2-0cebb0f46490'
    AND role_type = 'shelf_stocker'
    AND task_completed = true
    AND completion_photo_url IS NOT NULL
LIMIT 1;

-- Test if our JSONB building works
SELECT jsonb_build_object(
    'shelf_stocker', 
    'https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/completion-photos/test.png'
) as test_json_build;