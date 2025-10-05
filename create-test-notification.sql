-- Create a test notification and test the complete push notification flow

-- First, let's see what users exist
SELECT 'Available users:' as info, id, username, status 
FROM users 
WHERE status = 'active' 
LIMIT 5;

-- Create a test notification
INSERT INTO notifications (
    title,
    message,
    type,
    target_type,
    target_users,
    created_by,
    created_by_name,
    created_at
) VALUES (
    'Test Push Notification',
    'This is a test push notification to verify the system is working correctly',
    'system',
    'all_users',
    NULL,
    'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b', -- Using the user ID from the logs
    'System Test',
    NOW()
) RETURNING id, title, message, target_type, created_at;

-- Get the notification ID from the insert above and test the queue function
-- Note: Replace the UUID below with the actual ID returned from the INSERT above
DO $$
DECLARE
    test_notification_id UUID;
    queue_result TEXT;
BEGIN
    -- Get the most recent notification (the one we just created)
    SELECT id INTO test_notification_id
    FROM notifications
    ORDER BY created_at DESC
    LIMIT 1;
    
    RAISE NOTICE 'Testing with notification ID: %', test_notification_id;
    
    -- Test the queue function
    SELECT queue_push_notification(test_notification_id) INTO queue_result;
    
    RAISE NOTICE 'Queue function result: %', queue_result;
END $$;

-- Check what was queued
SELECT 
    'Queued notifications:' as info,
    nq.id,
    nq.notification_id,
    nq.user_id,
    nq.status,
    nq.created_at,
    n.title,
    n.message
FROM notification_queue nq
JOIN notifications n ON nq.notification_id = n.id
WHERE nq.created_at > NOW() - INTERVAL '5 minutes'
ORDER BY nq.created_at DESC;

-- Show current queue status
SELECT 
    'Queue summary:' as info,
    status,
    COUNT(*) as count
FROM notification_queue
GROUP BY status
ORDER BY status;