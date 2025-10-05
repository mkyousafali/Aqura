-- Test script to verify the push notification function is working

-- 1. Check if the function exists
SELECT 
    'Function Status' as test_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_proc p 
            JOIN pg_namespace n ON p.pronamespace = n.oid 
            WHERE n.nspname = 'public' AND p.proname = 'queue_push_notification'
        ) THEN 'Function EXISTS ✅'
        ELSE 'Function MISSING ❌'
    END as result;

-- 2. Check if there are any active push subscriptions
SELECT 
    'Push Subscriptions' as test_type,
    COUNT(*) as active_subscriptions,
    CASE 
        WHEN COUNT(*) > 0 THEN 'Subscriptions found ✅'
        ELSE 'NO SUBSCRIPTIONS ❌'
    END as result
FROM push_subscriptions ps
JOIN users u ON ps.user_id = u.id
WHERE u.status = 'active' AND ps.is_active = true;

-- 3. Check recent notifications that could be queued
SELECT 
    'Recent Notifications' as test_type,
    COUNT(*) as recent_count,
    CASE 
        WHEN COUNT(*) > 0 THEN 'Notifications available ✅'
        ELSE 'No recent notifications ❌'
    END as result
FROM notifications
WHERE created_at > NOW() - INTERVAL '24 hours';

-- 4. Check current queue status
SELECT 
    'Current Queue' as test_type,
    status,
    COUNT(*) as count
FROM notification_queue
GROUP BY status
ORDER BY status;

-- 5. Test the function with an existing notification (if any exists)
DO $$
DECLARE
    test_notification_id UUID;
    function_result TEXT;
BEGIN
    -- Get the most recent notification
    SELECT id INTO test_notification_id
    FROM notifications
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF test_notification_id IS NOT NULL THEN
        -- Test the function
        SELECT queue_push_notification(test_notification_id) INTO function_result;
        
        RAISE NOTICE 'Testing function with notification ID: %', test_notification_id;
        RAISE NOTICE 'Function result: %', function_result;
    ELSE
        RAISE NOTICE 'No notifications found to test with';
    END IF;
END $$;

-- 6. Show any new queue entries created by the test
SELECT 
    'New Queue Entries' as test_type,
    nq.id,
    nq.notification_id,
    nq.user_id,
    nq.status,
    nq.created_at,
    n.title as notification_title
FROM notification_queue nq
JOIN notifications n ON nq.notification_id = n.id
WHERE nq.created_at > NOW() - INTERVAL '5 minutes'
ORDER BY nq.created_at DESC;