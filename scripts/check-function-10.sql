-- Function 10: check_receiving_task_dependencies
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'check_receiving_task_dependencies' 
AND pronamespace = 'public'::regnamespace;
