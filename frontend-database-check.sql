-- Quick frontend database connection test
-- Run this and compare with what the frontend sees

-- Check what the frontend query should find
SELECT 
    'Current pending queue entries:' as info,
    COUNT(*) as total_pending
FROM notification_queue 
WHERE status = 'pending';

-- Check the exact query the frontend is running
SELECT 
    nq.id,
    nq.notification_id,
    nq.user_id,
    nq.device_id,
    nq.push_subscription_id,
    nq.payload,
    nq.status,
    nq.created_at,
    ps.endpoint,
    ps.p256dh,
    ps.auth
FROM notification_queue nq
LEFT JOIN push_subscriptions ps ON nq.push_subscription_id = ps.id
WHERE nq.status = 'pending'
ORDER BY nq.created_at ASC
LIMIT 10;

-- Check if there are push subscriptions with proper joins
SELECT 
    'Queue entries with subscriptions:' as info,
    COUNT(*) as count
FROM notification_queue nq
INNER JOIN push_subscriptions ps ON nq.push_subscription_id = ps.id
WHERE nq.status = 'pending' AND ps.is_active = true;

-- Check recent notification specifically
SELECT 
    'Recent notification queue check:' as info,
    nq.id,
    nq.status,
    nq.push_subscription_id,
    ps.id as subscription_exists,
    ps.is_active
FROM notification_queue nq
LEFT JOIN push_subscriptions ps ON nq.push_subscription_id = ps.id
WHERE nq.notification_id = '1a4030a4-b284-4439-b2fc-8e2d150e61f5'
LIMIT 5;