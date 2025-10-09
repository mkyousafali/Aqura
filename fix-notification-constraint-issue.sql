-- Fix notification table constraint issue
-- The error "there is no unique or exclusion constraint matching the ON CONFLICT specification" 
-- suggests there's a problematic ON CONFLICT clause in a trigger or function

-- 1. First, check the actual structure of the notifications table
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'notifications' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Check all constraints on notifications table
SELECT 
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    tc.is_deferrable,
    tc.initially_deferred
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
WHERE tc.table_name = 'notifications'
    AND tc.table_schema = 'public'
ORDER BY tc.constraint_type, tc.constraint_name;

-- 3. Check for unique constraints specifically
SELECT 
    tc.constraint_name,
    string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) as columns
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'notifications'
    AND tc.constraint_type = 'UNIQUE'
    AND tc.table_schema = 'public'
GROUP BY tc.constraint_name;

-- 4. Check for any triggers on the notifications table that might have ON CONFLICT
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement,
    action_condition
FROM information_schema.triggers 
WHERE event_object_table = 'notifications'
  AND event_object_schema = 'public'
ORDER BY trigger_name;

-- 5. Check the queue_push_notification function for any ON CONFLICT clauses
SELECT 
    routine_name,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'queue_push_notification'
  AND routine_schema = 'public';

-- 6. Look for any functions that insert into notifications with ON CONFLICT
SELECT 
    routine_name,
    routine_definition
FROM information_schema.routines 
WHERE routine_schema = 'public'
  AND routine_definition ILIKE '%on conflict%'
  AND routine_definition ILIKE '%notifications%';

-- 7. Check if there are any views or materialized views that might be causing issues
SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_schema = 'public'
  AND table_name ILIKE '%notification%'
ORDER BY table_name;

-- Success message
SELECT 'Notification constraint diagnostic completed!' as status;
SELECT 'Review the output above to identify the constraint issue' as note;