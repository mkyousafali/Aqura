-- Check for triggers on receiving_records table that might reference payment_status

-- 1. List all triggers on receiving_records
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'receiving_records'
AND event_object_schema = 'public';

-- 2. Find trigger functions that might reference payment_status
SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname IN (
    SELECT action_statement::text
    FROM information_schema.triggers
    WHERE event_object_table = 'receiving_records'
)
AND pg_get_functiondef(p.oid) ILIKE '%payment_status%';

-- 3. Check all triggers across related tables
SELECT 
    t.event_object_table as table_name,
    t.trigger_name,
    t.action_statement
FROM information_schema.triggers t
WHERE t.event_object_schema = 'public'
AND t.event_object_table IN ('receiving_records', 'vendor_payment_schedule')
ORDER BY t.event_object_table, t.trigger_name;
