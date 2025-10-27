-- Find the exact function causing the error
-- Run each query separately if needed

-- Query 1: Find the process_clearance_certificate_generation function
SELECT pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname = 'process_clearance_certificate_generation';

-- Query 2: Find get_tasks_for_receiving_record function
-- SELECT pg_get_functiondef(p.oid) as function_definition
-- FROM pg_proc p
-- JOIN pg_namespace n ON p.pronamespace = n.oid
-- WHERE n.nspname = 'public'
-- AND p.proname = 'get_tasks_for_receiving_record';

-- Query 3: List all function names that reference payment_status
-- SELECT p.proname as function_name
-- FROM pg_proc p
-- JOIN pg_namespace n ON p.pronamespace = n.oid
-- WHERE n.nspname = 'public'
-- AND pg_get_functiondef(p.oid) ILIKE '%payment_status%'
-- ORDER BY p.proname;
