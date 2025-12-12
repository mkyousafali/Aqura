-- Run this query in Supabase SQL Editor to find all triggers on orders table

SELECT 
    tgname as trigger_name,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger 
WHERE tgrelid = 'orders'::regclass
AND tgname NOT LIKE 'RI_%';
