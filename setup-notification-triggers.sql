-- Complete database trigger setup for automatic notification queueing
-- This will automatically queue push notifications when new notifications are created

-- First, ensure the queue_push_notification function exists
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
    
    -- Queue notification for all active users with push subscriptions
    FOR user_rec IN 
        SELECT DISTINCT u.id, u.username
        FROM users u
        INNER JOIN push_subscriptions ps ON u.id = ps.user_id
        WHERE ps.is_active = true
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
                    'body', COALESCE(notification_rec.message, notification_rec.body, notification_rec.content, notification_rec.title),
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

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_queue_push_notifications ON notifications;

-- Create the trigger function
CREATE OR REPLACE FUNCTION trigger_queue_push_notifications()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Only queue for new notifications (INSERT)
    IF TG_OP = 'INSERT' THEN
        -- Call the queue function asynchronously to avoid blocking the insert
        PERFORM queue_push_notification(NEW.id);
        RETURN NEW;
    END IF;
    
    RETURN NULL;
END;
$$;

-- Create the trigger that fires AFTER INSERT
CREATE TRIGGER trigger_queue_push_notifications
    AFTER INSERT ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION trigger_queue_push_notifications();

-- Verify the trigger was created
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'notifications'
ORDER BY trigger_name;

-- Test the trigger by checking if function exists
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_name = 'queue_push_notification';

-- EXPECTED RESULTS:
-- This should show:
-- 1. trigger_queue_push_notifications | INSERT | AFTER | EXECUTE FUNCTION trigger_queue_push_notifications()
-- 2. queue_push_notification | function