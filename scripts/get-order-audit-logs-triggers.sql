-- Run this query in Supabase SQL Editor to find all triggers on order_audit_logs

SELECT 
    tgname as trigger_name,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger 
WHERE tgrelid = 'order_audit_logs'::regclass
AND tgname NOT LIKE 'RI_%';
