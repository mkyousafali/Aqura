-- Check for any database cleanup functions or triggers related to notification_queue
-- 1. Check for any functions that might delete from notification_queue
SELECT 
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND (
    routine_definition ILIKE '%DELETE FROM notification_queue%'
    OR routine_definition ILIKE '%notification_queue%'
    OR routine_name ILIKE '%cleanup%'
    OR routine_name ILIKE '%clean%'
)
ORDER BY routine_name;

-- 2. Check for any triggers that might affect notification_queue
SELECT 
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation,
    action_statement
FROM information_schema.triggers 
WHERE (
    trigger_name ILIKE '%cleanup%'
    OR trigger_name ILIKE '%clean%'
    OR event_object_table = 'notification_queue'
)
ORDER BY trigger_name;

-- 3. Check for any cron jobs or scheduled functions (if pg_cron is enabled)
SELECT 
    jobname,
    schedule,
    command,
    active
FROM cron.job 
WHERE command ILIKE '%notification_queue%'
   OR command ILIKE '%cleanup%'
   OR jobname ILIKE '%cleanup%';

-- 4. Check current notification_queue entries to see if anything is being auto-deleted
SELECT 
    'Current notification queue status:' as info,
    status,
    COUNT(*) as count,
    MIN(created_at) as oldest,
    MAX(created_at) as newest
FROM notification_queue
GROUP BY status
ORDER BY status;