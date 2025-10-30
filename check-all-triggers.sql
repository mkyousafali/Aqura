-- Check all triggers on notifications table (not just push-related)
SELECT 
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    tgenabled as enabled,
    tgtype as trigger_type,
    proname as function_name,
    CASE 
        WHEN tgtype & 2 = 2 THEN 'BEFORE'
        WHEN tgtype & 4 = 4 THEN 'INSTEAD OF'
        ELSE 'AFTER'
    END as timing,
    CASE 
        WHEN tgtype & 16 = 16 THEN 'INSERT'
        WHEN tgtype & 8 = 8 THEN 'DELETE'
        WHEN tgtype & 4 = 4 THEN 'UPDATE'
        ELSE 'UNKNOWN'
    END as event
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'notifications'::regclass
AND NOT tgisinternal  -- Exclude internal triggers
ORDER BY tgname;
