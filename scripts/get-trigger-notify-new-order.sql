-- Run this query in Supabase SQL Editor to get trigger_notify_new_order function

SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'trigger_notify_new_order' 
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
