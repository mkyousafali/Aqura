-- Check remaining functions that use role_type
-- Batch 1: Functions 7-11

-- Function 7: check_erp_sync_status
SELECT 'Function: check_erp_sync_status' as info;
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'check_erp_sync_status' 
AND pronamespace = 'public'::regnamespace;

SELECT '---' as separator;

-- Function 8: check_erp_sync_status_for_record
SELECT 'Function: check_erp_sync_status_for_record' as info;
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'check_erp_sync_status_for_record' 
AND pronamespace = 'public'::regnamespace;

SELECT '---' as separator;

-- Function 9: check_receiving_task_dependencies
SELECT 'Function: check_receiving_task_dependencies' as info;
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'check_receiving_task_dependencies' 
AND pronamespace = 'public'::regnamespace;

SELECT '---' as separator;

-- Function 10: complete_receiving_task
SELECT 'Function: complete_receiving_task' as info;
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'complete_receiving_task' 
AND pronamespace = 'public'::regnamespace
LIMIT 1;

SELECT '---' as separator;

-- Function 11: complete_receiving_task_fixed
SELECT 'Function: complete_receiving_task_fixed' as info;
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'complete_receiving_task_fixed' 
AND pronamespace = 'public'::regnamespace;
