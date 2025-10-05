-- Test Push Notification System
-- Check if the notification system is working properly

-- 1. Check if push_subscriptions table has any active subscriptions
SELECT 'Push Subscriptions Check:' as test;
SELECT 
    id,
    user_id,
    device_id,
    created_at,
    is_active
FROM push_subscriptions 
WHERE is_active = true
ORDER BY created_at DESC
LIMIT 5;

-- 2. Check if notification_queue table has any pending notifications
SELECT 'Notification Queue Check:' as test;
SELECT 
    id,
    notification_id,
    user_id,
    device_id,
    status,
    created_at,
    error_message
FROM notification_queue 
ORDER BY created_at DESC
LIMIT 10;

-- 3. Check recent notifications
SELECT 'Recent Notifications:' as test;
SELECT 
    id,
    title,
    message,
    type,
    status,
    created_at,
    created_by
FROM notifications 
ORDER BY created_at DESC
LIMIT 5;

-- 4. Test the queue_push_notification function
SELECT 'Testing queue_push_notification function:' as test;

-- First, let's see if the function exists
SELECT 
    routine_name,
    routine_type,
    specific_name
FROM information_schema.routines 
WHERE routine_name = 'queue_push_notification'
    AND routine_schema = 'public';

-- 5. Check if there are any errors in notification processing
SELECT 'Error Analysis:' as test;
SELECT 
    status,
    COUNT(*) as count,
    MAX(created_at) as latest_attempt
FROM notification_queue
GROUP BY status
ORDER BY count DESC;

-- 6. Check notification recipients
SELECT 'Notification Recipients Check:' as test;
SELECT 
    nr.id,
    nr.notification_id,
    nr.user_id,
    nr.is_read,
    nr.is_dismissed,
    nr.created_at,
    n.title,
    n.type
FROM notification_recipients nr
JOIN notifications n ON nr.notification_id = n.id
ORDER BY nr.created_at DESC
LIMIT 5;