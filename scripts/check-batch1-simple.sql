-- Quick check if functions exist
SELECT proname as function_name, 
       pronargs as num_args
FROM pg_proc 
WHERE proname IN (
  'check_erp_sync_status',
  'check_erp_sync_status_for_record', 
  'check_receiving_task_dependencies',
  'complete_receiving_task',
  'complete_receiving_task_simple'
)
AND pronamespace = 'public'::regnamespace
ORDER BY proname;
