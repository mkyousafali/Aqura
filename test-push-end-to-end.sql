-- Test Push Notification End-to-End
-- This will create a test notification and check if it gets queued properly

-- 1. First check current state
SELECT 'Current Push Subscriptions:' as test;
SELECT COUNT(*) as active_subscriptions FROM push_subscriptions WHERE is_active = true;

SELECT 'Current Notification Queue:' as test;
SELECT COUNT(*) as pending_notifications FROM notification_queue WHERE status = 'pending';

-- 2. Create a test notification
INSERT INTO notifications (
    title,
    message,
    type,
    status,
    created_by,
    created_at
) VALUES (
    'Test Push Notification',
    'This is a test to check if push notifications are working',
    'system',
    'active',
    (SELECT id FROM users WHERE username = 'madmin' LIMIT 1),
    NOW()
) RETURNING id, title, created_at;

-- 3. Get the notification ID for testing
WITH test_notification AS (
    SELECT id FROM notifications 
    WHERE title = 'Test Push Notification' 
    ORDER BY created_at DESC 
    LIMIT 1
)
-- 4. Create notification recipients for all active users
INSERT INTO notification_recipients (
    notification_id,
    user_id,
    is_read,
    is_dismissed,
    delivery_status,
    created_at
)
SELECT 
    tn.id,
    u.id,
    false,
    false,
    'pending',
    NOW()
FROM test_notification tn
CROSS JOIN users u
WHERE u.status = 'active'
RETURNING id, notification_id, user_id, delivery_status;

-- 5. Now test the queue_push_notification function
WITH test_notification AS (
    SELECT id FROM notifications 
    WHERE title = 'Test Push Notification' 
    ORDER BY created_at DESC 
    LIMIT 1
)
SELECT queue_push_notification(id) as queue_result
FROM test_notification;

-- 6. Check if notifications were queued
SELECT 'After Queueing:' as test;
SELECT 
    nq.id,
    nq.notification_id,
    nq.user_id,
    nq.device_id,
    nq.status,
    nq.created_at,
    nq.error_message,
    n.title
FROM notification_queue nq
JOIN notifications n ON nq.notification_id = n.id
WHERE n.title = 'Test Push Notification'
ORDER BY nq.created_at DESC;

-- 7. Check notification recipients (with type-safe JOIN)
SELECT 'Notification Recipients Status:' as test;
SELECT 
    nr.id,
    nr.notification_id,
    nr.user_id,
    nr.delivery_status,
    nr.is_read,
    u.username
FROM notification_recipients nr
JOIN notifications n ON nr.notification_id = n.id
LEFT JOIN users u ON nr.user_id = u.id  -- Use LEFT JOIN in case of any orphaned records
WHERE n.title = 'Test Push Notification'
ORDER BY nr.created_at DESC;