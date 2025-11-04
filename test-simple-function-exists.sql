-- =====================================================
-- TEST IF SIMPLE FUNCTION EXISTS
-- =====================================================

-- Check if the function exists
SELECT 
    proname as function_name,
    pg_get_function_identity_arguments(oid) as arguments
FROM pg_proc 
WHERE proname = 'complete_receiving_task_simple';

-- If it doesn't exist, this will show no results
-- If it exists, you'll see the function details