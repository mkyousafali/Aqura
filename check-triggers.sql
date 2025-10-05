-- Check existing triggers on notifications table
SELECT 
    trigger_name,
    event_manipulation,
    action_statement,
    action_timing
FROM information_schema.triggers 
WHERE event_object_table = 'notifications'
ORDER BY trigger_name;

-- Check if the queue_push_notification function exists
SELECT 
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'queue_push_notification';

-- Check recent notifications to see their IDs
SELECT 
    id,
    title,
    created_at,
    created_by
FROM notifications 
ORDER BY created_at DESC 
LIMIT 5;

-- Check what's currently in the notification queue
SELECT 
    id,
    notification_id,
    user_id,
    status,
    created_at
FROM notification_queue 
ORDER BY created_at DESC 
LIMIT 10;