-- Simple fix: Replace the queue function without any potential email references
-- Run this to completely replace the function with the corrected version

-- Drop and recreate the function to ensure no cached email references
DROP FUNCTION IF EXISTS queue_push_notification(uuid);

-- Create the corrected function
CREATE OR REPLACE FUNCTION queue_push_notification(p_notification_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    notification_rec record;
    user_rec record;
    device_rec record;
    queued_count integer := 0;
BEGIN
    -- Get notification details
    SELECT * INTO notification_rec 
    FROM notifications 
    WHERE id = p_notification_id;
    
    IF notification_rec IS NULL THEN
        RETURN 'Notification not found';
    END IF;
    
    -- Queue notification for all active users with push subscriptions (simplified query)
    FOR user_rec IN 
        SELECT DISTINCT u.id, u.username
        FROM users u
        WHERE u.id IN (
            SELECT DISTINCT ps.user_id 
            FROM push_subscriptions ps 
            WHERE ps.is_active = true
        )
        AND u.status = 'active'
    LOOP
        -- Queue notification for each device of this user
        FOR device_rec IN
            SELECT id, device_id, endpoint, p256dh, auth
            FROM push_subscriptions 
            WHERE user_id = user_rec.id 
            AND is_active = true
        LOOP
            -- Create the push notification payload
            INSERT INTO notification_queue (
                notification_id,
                user_id,
                device_id,
                push_subscription_id,
                status,
                payload
            ) VALUES (
                p_notification_id,
                user_rec.id,
                device_rec.device_id,
                device_rec.id,
                'pending',
                jsonb_build_object(
                    'title', notification_rec.title,
                    'body', COALESCE(notification_rec.message, notification_rec.title),
                    'icon', '/icons/icon-192x192.png',
                    'badge', '/icons/icon-96x96.png',
                    'tag', 'aqura-notification-' || p_notification_id::text,
                    'data', jsonb_build_object(
                        'notification_id', p_notification_id,
                        'url', '/notifications',
                        'created_at', notification_rec.created_at,
                        'sender', COALESCE(notification_rec.created_by::text, user_rec.username, 'System')
                    )
                )
            );
            
            queued_count := queued_count + 1;
        END LOOP;
    END LOOP;
    
    RETURN 'Queued ' || queued_count || ' push notifications for notification ' || p_notification_id;
END;
$$;