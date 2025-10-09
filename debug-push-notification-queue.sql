-- Debug push notification queue issue
-- The notification is created successfully but push notifications aren't being queued

-- 1. Check if notification_queue table exists and its structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'notification_queue' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Check recent notifications to see if they exist
SELECT 
    id,
    title,
    target_type,
    total_recipients,
    created_at
FROM notifications 
ORDER BY created_at DESC 
LIMIT 5;

-- 3. Check notification_recipients to see if they were populated
SELECT 
    COUNT(*) as total_recipients,
    COUNT(DISTINCT notification_id) as notifications_with_recipients,
    COUNT(DISTINCT user_id) as unique_users
FROM notification_recipients
WHERE created_at > NOW() - INTERVAL '1 hour';

-- 4. Check the queue_push_notification function definition
SELECT 
    routine_name,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'queue_push_notification'
  AND routine_schema = 'public';

-- 5. Check if there are any push_subscriptions (required for notifications to be queued)
SELECT 
    COUNT(*) as total_subscriptions,
    COUNT(DISTINCT user_id) as unique_users_with_subscriptions,
    COUNT(CASE WHEN is_active = true THEN 1 END) as active_subscriptions
FROM push_subscriptions;

-- 6. Check notification_queue for any entries
SELECT 
    COUNT(*) as total_queue_entries,
    status,
    COUNT(*) as count_by_status
FROM notification_queue
GROUP BY status
ORDER BY status;

-- 7. Check recent notification_queue entries
SELECT 
    nq.*,
    n.title,
    u.username
FROM notification_queue nq
JOIN notifications n ON nq.notification_id = n.id
JOIN users u ON nq.user_id = u.id
ORDER BY nq.created_at DESC
LIMIT 10;

-- Success message
SELECT 'Push notification queue diagnostic completed!' as status;
SELECT 'Check the results above to identify why push notifications are not being queued' as note;