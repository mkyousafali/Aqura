-- Check current state of the database
-- 1. Check if queue_push_notification function exists and what it looks like
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_name = 'queue_push_notification'
AND routine_schema = 'public';

-- 2. Check notification_queue table structure
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'notification_queue'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Check current notification_queue entries
SELECT 
    'Current notification queue status:' as info,
    status,
    COUNT(*) as count
FROM notification_queue
GROUP BY status
ORDER BY status;

-- 4. Check recent notifications
SELECT 
    'Recent notifications (last 24h):' as info,
    COUNT(*) as count,
    target_type,
    type
FROM notifications
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY target_type, type
ORDER BY count DESC;

-- 5. Check push subscriptions
SELECT 
    'Active push subscriptions:' as info,
    COUNT(*) as count
FROM push_subscriptions ps
JOIN users u ON ps.user_id = u.id
WHERE u.status = 'active' AND ps.is_active = true;

-- 6. Check if trigger exists
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name LIKE '%queue_push%'
AND event_object_table = 'notifications';