-- Function 7: check_erp_sync_status
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'check_erp_sync_status' 
AND pronamespace = 'public'::regnamespace;
