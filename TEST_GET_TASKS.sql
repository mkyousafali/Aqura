-- TEST: Check if get_tasks_for_receiving_record function works
-- Run this to see what the function returns

-- Check if function exists
SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p 
JOIN pg_namespace n ON p.pronamespace = n.oid 
WHERE n.nspname = 'public' 
AND p.proname = 'get_tasks_for_receiving_record';

-- Test the function with a sample UUID (this might fail if no data exists)
-- Replace with your actual receiving_record_id
SELECT * FROM get_tasks_for_receiving_record('6cd3c3cb-a66b-48f4-bad2-5a17a0eb2769'::UUID);