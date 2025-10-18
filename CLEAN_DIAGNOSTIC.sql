-- DIAGNOSTIC: Check current function signatures in database
-- Run this in Supabase SQL Editor to see what functions exist

-- Check create_task function signature
SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as result_type
FROM pg_proc p 
JOIN pg_namespace n ON p.pronamespace = n.oid 
WHERE n.nspname = 'public' 
AND p.proname = 'create_task';

-- Check generate_clearance_certificate_tasks function signature  
SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as result_type
FROM pg_proc p 
JOIN pg_namespace n ON p.pronamespace = n.oid 
WHERE n.nspname = 'public' 
AND p.proname = 'generate_clearance_certificate_tasks';

-- Check all functions with 'task' in the name
SELECT 
    p.proname as function_name,
    array_length(string_to_array(pg_get_function_arguments(p.oid), ','), 1) as param_count
FROM pg_proc p 
JOIN pg_namespace n ON p.pronamespace = n.oid 
WHERE n.nspname = 'public' 
AND p.proname LIKE '%task%'
ORDER BY p.proname;