-- Fix push notification queue issue
-- The problem is likely that queue_push_notification only creates notification_queue entries
-- for users who have active push_subscriptions, but most users don't have them

-- 1. Check current push subscriptions
SELECT 
    COUNT(*) as total_subscriptions,
    COUNT(DISTINCT user_id) as users_with_subscriptions,
    COUNT(CASE WHEN is_active = true THEN 1 END) as active_subscriptions,
    COUNT(CASE WHEN device_type = 'mobile' THEN 1 END) as mobile_subscriptions,
    COUNT(CASE WHEN device_type = 'desktop' THEN 1 END) as desktop_subscriptions
FROM push_subscriptions;

-- 2. Show some sample push subscriptions to understand the data
SELECT 
    ps.user_id,
    u.username,
    ps.device_type,
    ps.is_active,
    ps.last_seen,
    ps.created_at
FROM push_subscriptions ps
JOIN users u ON ps.user_id = u.id
ORDER BY ps.created_at DESC
LIMIT 10;

-- 3. Check how many users are active but don't have push subscriptions
SELECT 
    COUNT(*) as active_users_without_push_subscriptions
FROM users u
WHERE u.status = 'active'
  AND u.id NOT IN (
      SELECT DISTINCT user_id 
      FROM push_subscriptions 
      WHERE is_active = true
  );

-- 4. If the issue is lack of push subscriptions, let's check the queue_push_notification function
-- to see if it should still create queue entries even without push subscriptions
SELECT 
    routine_name,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_name = 'queue_push_notification'
  AND routine_schema = 'public';

-- 5. Temporary fix: Modify the queue_push_notification function to create queue entries 
-- for all users, not just those with push subscriptions
-- This will allow the push notification processor to work even if users haven't registered for push notifications

-- Get the current function definition first to understand what needs to be changed
-- (This will show in the query results)

-- Success message
SELECT 'Push notification diagnostic completed!' as status;
SELECT 'If most users do not have push subscriptions, that is the cause of the issue' as analysis;
SELECT 'The queue_push_notification function may need to be modified to queue notifications for all users' as solution;