-- ============================================================
-- COMPLETE DIAGNOSTIC - CHECK EXISTING SETUP
-- ============================================================
-- Run this FIRST to see current state before making any changes
-- ============================================================

-- 1. Check ALL triggers on notifications table
SELECT 
    '1️⃣ ALL TRIGGERS ON NOTIFICATIONS' as check_name,
    tgname as trigger_name,
    CASE WHEN tgenabled = 'O' THEN 'enabled' ELSE 'disabled' END as status,
    proname as calls_function
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'notifications'::regclass
AND NOT tgisinternal
ORDER BY tgname;

-- 2. Check for recipient creation trigger/function
SELECT 
    '2️⃣ RECIPIENT CREATION FUNCTIONS' as check_name,
    proname as function_name,
    prosrc as function_body_preview
FROM pg_proc
WHERE proname LIKE '%recipient%' 
   OR proname LIKE '%create_notification%'
   OR prosrc LIKE '%notification_recipients%'
ORDER BY proname;

-- 3. Check queue_push_notification function exists
SELECT 
    '3️⃣ PUSH QUEUE FUNCTION' as check_name,
    proname as function_name,
    CASE 
        WHEN proname = 'queue_push_notification' THEN '✅ Exists'
        ELSE 'Function name: ' || proname
    END as status
FROM pg_proc
WHERE proname IN ('queue_push_notification', 'queue_push_notification_trigger');

-- 4. Check what triggers call what functions
SELECT 
    '4️⃣ TRIGGER → FUNCTION MAPPING' as check_name,
    t.tgname as trigger_name,
    p.proname as function_name,
    t.tgrelid::regclass as on_table
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE t.tgrelid = 'notifications'::regclass
AND NOT t.tgisinternal
ORDER BY t.tgname;

-- 5. Check notification_recipients table structure
SELECT 
    '5️⃣ NOTIFICATION_RECIPIENTS TABLE' as check_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'notification_recipients'
ORDER BY ordinal_position;

-- 6. Check notification_queue table structure  
SELECT 
    '6️⃣ NOTIFICATION_QUEUE TABLE' as check_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'notification_queue'
ORDER BY ordinal_position;

-- 7. Sample recent notifications and their recipients
SELECT 
    '7️⃣ RECENT NOTIFICATIONS WITH RECIPIENTS' as check_name,
    n.id as notification_id,
    n.title,
    n.status,
    n.created_at,
    (SELECT COUNT(*) FROM notification_recipients WHERE notification_id = n.id) as recipient_count,
    (SELECT COUNT(*) FROM notification_queue WHERE notification_id = n.id) as queue_count
FROM notifications n
ORDER BY n.created_at DESC
LIMIT 5;

-- 8. Check if there's a trigger that creates recipients
SELECT 
    '8️⃣ TRIGGERS THAT MIGHT CREATE RECIPIENTS' as check_name,
    t.tgname as trigger_name,
    t.tgrelid::regclass as on_table,
    p.proname as function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE (p.prosrc LIKE '%notification_recipients%' 
   OR p.prosrc LIKE '%INSERT INTO notification_recipients%'
   OR p.proname LIKE '%recipient%')
AND NOT t.tgisinternal;

-- 9. Show queue_push_notification function body (partial)
SELECT 
    '9️⃣ QUEUE_PUSH_NOTIFICATION FUNCTION BODY' as check_name,
    substring(prosrc from 1 for 500) as function_code_preview
FROM pg_proc
WHERE proname = 'queue_push_notification';

-- ============================================================
-- SUMMARY
-- ============================================================
SELECT 
    '📊 SUMMARY' as section,
    (SELECT COUNT(*) FROM pg_trigger WHERE tgrelid = 'notifications'::regclass AND NOT tgisinternal) as total_triggers_on_notifications,
    (SELECT COUNT(*) FROM pg_trigger t JOIN pg_proc p ON t.tgfoid = p.oid 
     WHERE t.tgrelid = 'notifications'::regclass AND p.proname LIKE '%push%' AND NOT t.tgisinternal) as push_related_triggers,
    (SELECT CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'queue_push_notification') 
            THEN 'YES' ELSE 'NO' END) as queue_function_exists,
    (SELECT CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE prosrc LIKE '%INSERT INTO notification_recipients%') 
            THEN 'YES' ELSE 'NO' END) as recipient_creation_exists;
