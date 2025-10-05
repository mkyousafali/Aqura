-- Quick Push Notification Status Check
-- Check if notifications are being queued for push delivery

SELECT 'Push Notification System Status:' as check_type;

-- 1. Check push subscriptions (devices registered)
SELECT 
    'Active Push Subscriptions' as metric,
    COUNT(*) as count
FROM push_subscriptions 
WHERE is_active = true;

-- 2. Check notification queue (notifications waiting to be sent)
SELECT 
    'Notification Queue Status' as metric,
    status,
    COUNT(*) as count
FROM notification_queue 
GROUP BY status
ORDER BY count DESC;

-- 3. Check recent notifications with recipients
SELECT 
    'Recent Notifications with Recipients' as metric,
    n.title,
    n.created_at,
    COUNT(nr.id) as recipient_count,
    COUNT(CASE WHEN nr.delivery_status = 'pending' THEN 1 END) as pending_delivery,
    COUNT(CASE WHEN nr.delivery_status = 'delivered' THEN 1 END) as delivered
FROM notifications n
LEFT JOIN notification_recipients nr ON n.id = nr.notification_id
WHERE n.created_at >= NOW() - INTERVAL '1 hour'
GROUP BY n.id, n.title, n.created_at
ORDER BY n.created_at DESC
LIMIT 5;

-- 4. Check if queue_push_notification function is working
SELECT 'Testing queue_push_notification function' as check_type;

-- Get the latest test notification
WITH latest_notification AS (
    SELECT id FROM notifications 
    WHERE title LIKE 'Test Push%' 
    ORDER BY created_at DESC 
    LIMIT 1
)
SELECT 
    'Function Test Result' as test,
    ln.id as notification_id,
    queue_push_notification(ln.id) as function_result
FROM latest_notification ln;

-- 5. Check if items were added to queue after function call
SELECT 
    'Queue Items After Function Call' as check_type,
    nq.notification_id,
    nq.user_id,
    nq.device_id,
    nq.status,
    nq.created_at
FROM notification_queue nq
JOIN notifications n ON nq.notification_id = n.id
WHERE n.title LIKE 'Test Push%'
ORDER BY nq.created_at DESC;