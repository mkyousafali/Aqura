-- Debug why new notifications aren't being queued

-- 1. Check if the triggers exist and are active
SELECT 
    'Database Triggers:' as info,
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing
FROM information_schema.triggers 
WHERE event_object_table = 'notifications'
ORDER BY trigger_name;

-- 2. Check the queue function specifically for the notification that failed
SELECT queue_push_notification('1a4030a4-b284-4439-b2fc-8e2d150e61f5'::UUID) as manual_queue_test;

-- 3. Check if there are active users with push subscriptions
SELECT 
    'Active Users with Push Subscriptions:' as info,
    COUNT(DISTINCT ps.user_id) as users_with_subscriptions,
    COUNT(*) as total_subscriptions
FROM push_subscriptions ps
JOIN users u ON ps.user_id = u.id
WHERE u.status = 'active' AND ps.is_active = true;

-- 4. Check the specific user creating notifications
SELECT 
    'Creator User Check:' as info,
    u.id,
    u.username,
    u.status,
    ps.id as push_subscription_id,
    ps.is_active as subscription_active
FROM users u
LEFT JOIN push_subscriptions ps ON u.id = ps.user_id
WHERE u.username = 'madmin';

-- 5. Check recent notifications and their queue status
SELECT 
    'Recent Notifications:' as info,
    n.id,
    n.title,
    n.target_type,
    n.created_at,
    COUNT(nq.id) as queue_entries
FROM notifications n
LEFT JOIN notification_queue nq ON n.id = nq.notification_id
WHERE n.created_at > NOW() - INTERVAL '1 hour'
GROUP BY n.id, n.title, n.target_type, n.created_at
ORDER BY n.created_at DESC;

-- 6. Test the function manually with a specific user
DO $$
DECLARE
    result TEXT;
BEGIN
    -- Test if the function works with the notification ID that failed
    SELECT queue_push_notification('1a4030a4-b284-4439-b2fc-8e2d150e61f5'::UUID) INTO result;
    RAISE NOTICE 'Manual queue test result: %', result;
END $$;