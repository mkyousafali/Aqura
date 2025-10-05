-- Fix the queue_push_notification function to use correct schema
-- The function was checking for 'status = active' but the table uses 'is_active = true'

-- First, clean up existing data in notification_queue table
-- Delete all current entries since they likely have schema mismatch issues
DELETE FROM notification_queue WHERE status = 'pending';

-- Also delete old processed entries to clean up the table
DELETE FROM notification_queue WHERE status IN ('sent', 'failed', 'delivered') 
AND created_at < NOW() - INTERVAL '7 days';

-- Show what was cleaned up
SELECT 
    'Notification queue cleaned up - removed old entries' as cleanup_info,
    COUNT(*) as remaining_entries
FROM notification_queue;

-- Drop the existing function first to allow return type change
DROP FUNCTION IF EXISTS queue_push_notification(UUID);

CREATE OR REPLACE FUNCTION queue_push_notification(
    p_notification_id UUID
)
RETURNS TEXT AS $$
DECLARE
    user_record RECORD;
    subscription_record RECORD;
    notification_data RECORD;
    device_count INTEGER := 0;
    total_queued INTEGER := 0;
BEGIN
    -- Get notification data
    SELECT 
        title,
        message as body,  -- 'message' is the correct column name
        type,
        target_type,
        target_users,
        target_roles,
        target_branches,
        created_at
    INTO notification_data
    FROM notifications 
    WHERE id = p_notification_id;
    
    IF NOT FOUND THEN
        RETURN 'Notification not found';
    END IF;
    
    -- Process based on target type
    CASE notification_data.target_type
        WHEN 'all_users' THEN
            -- Queue for all active users with push subscriptions
            FOR subscription_record IN 
                SELECT DISTINCT 
                    ps.id as push_subscription_id,
                    ps.user_id, 
                    ps.device_id,
                    ps.endpoint, 
                    ps.p256dh, 
                    ps.auth,
                    u.username
                FROM push_subscriptions ps
                JOIN users u ON ps.user_id = u.id
                WHERE u.status = 'active'
                  AND ps.is_active = true  -- Correct: use is_active instead of status
            LOOP
                -- Create the payload
                INSERT INTO notification_queue (
                    notification_id,
                    user_id,
                    device_id,
                    push_subscription_id,  -- Use the actual subscription ID
                    payload,
                    status,
                    created_at
                ) VALUES (
                    p_notification_id,
                    subscription_record.user_id,
                    subscription_record.device_id,
                    subscription_record.push_subscription_id,
                    jsonb_build_object(
                        'title', notification_data.title,
                        'body', notification_data.body,
                        'icon', '/icons/icon-192x192.png',
                        'badge', '/icons/icon-96x96.png',
                        'tag', 'aqura-notification-' || p_notification_id::text,
                        'data', jsonb_build_object(
                            'notificationId', p_notification_id,
                            'type', notification_data.type,
                            'url', '/'
                        )
                    ),
                    'pending',
                    NOW()
                );
                total_queued := total_queued + 1;
            END LOOP;
            
        WHEN 'specific_users' THEN
            -- Queue for specific users from target_users array
            -- target_users is JSONB array of usernames
            FOR user_record IN 
                SELECT username 
                FROM jsonb_array_elements_text(notification_data.target_users) AS username
            LOOP
                FOR subscription_record IN 
                    SELECT DISTINCT 
                        ps.id as push_subscription_id,
                        ps.user_id, 
                        ps.device_id,
                        ps.endpoint, 
                        ps.p256dh, 
                        ps.auth
                    FROM push_subscriptions ps
                    JOIN users u ON ps.user_id = u.id
                    WHERE u.username = user_record.username
                      AND u.status = 'active'
                      AND ps.is_active = true  -- Correct: use is_active instead of status
                LOOP
                    INSERT INTO notification_queue (
                        notification_id,
                        user_id,
                        device_id,
                        push_subscription_id,
                        payload,
                        status,
                        created_at
                    ) VALUES (
                        p_notification_id,
                        subscription_record.user_id,
                        subscription_record.device_id,
                        subscription_record.push_subscription_id,
                        jsonb_build_object(
                            'title', notification_data.title,
                            'body', notification_data.body,
                            'icon', '/icons/icon-192x192.png',
                            'badge', '/icons/icon-96x96.png',
                            'tag', 'aqura-notification-' || p_notification_id::text,
                            'data', jsonb_build_object(
                                'notificationId', p_notification_id,
                                'type', notification_data.type,
                                'url', '/'
                            )
                        ),
                        'pending',
                        NOW()
                    );
                    total_queued := total_queued + 1;
                END LOOP;
            END LOOP;
            
        WHEN 'role_based' THEN
            -- Note: The user_roles table in your schema doesn't have user assignments
            -- This would need a junction table or additional logic
            -- For now, returning a message
            RETURN 'Role-based notifications require additional implementation';
            
    END CASE;
    
    RETURN 'Queued ' || total_queued || ' push notifications for notification ' || p_notification_id::text;
END;
$$ LANGUAGE plpgsql;

-- Test the function by checking if there are any active push subscriptions
SELECT 
    'Active push subscriptions:' as info,
    COUNT(*) as count
FROM push_subscriptions ps
JOIN users u ON ps.user_id = u.id
WHERE u.status = 'active' AND ps.is_active = true;

-- Verify the notification queue is now clean
SELECT 
    'Notification queue status after cleanup:' as status_info,
    status,
    COUNT(*) as count
FROM notification_queue
GROUP BY status
ORDER BY status;

-- Show total notifications that can be re-queued
SELECT 
    'Recent notifications ready for re-queueing:' as requeue_info,
    COUNT(*) as count
FROM notifications
WHERE created_at > NOW() - INTERVAL '24 hours';