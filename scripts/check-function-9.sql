-- Function 9: check_erp_sync_status_for_record
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'check_erp_sync_status_for_record' 
AND pronamespace = 'public'::regnamespace;
