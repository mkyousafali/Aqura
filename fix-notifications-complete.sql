-- Complete fix for notifications table issues
-- 1. Clean up duplicate triggers 
-- 2. Fix the queue function to use correct column names

-- First, drop all duplicate triggers
DROP TRIGGER IF EXISTS trigger_notification_push_queue ON notifications;
DROP TRIGGER IF EXISTS trigger_queue_push_notification ON notifications;  
DROP TRIGGER IF EXISTS trigger_queue_push_notifications ON notifications;

-- Drop and recreate the function with correct column names
DROP FUNCTION IF EXISTS queue_push_notification(uuid);
DROP FUNCTION IF EXISTS trigger_queue_push_notifications();

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
    -- Get notification details with correct column names
    SELECT 
        id, 
        title, 
        message, 
        created_by, 
        created_by_name,
        created_at,
        type,
        priority
    INTO notification_rec 
    FROM notifications 
    WHERE id = p_notification_id;
    
    IF notification_rec IS NULL THEN
        RETURN 'Notification not found';
    END IF;
    
    -- Queue notification for all active users with push subscriptions
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
            -- Create the push notification payload with correct field names
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
                    'body', notification_rec.message,  -- Use 'message' field from notifications table
                    'icon', '/icons/icon-192x192.png',
                    'badge', '/icons/icon-96x96.png',
                    'tag', 'aqura-notification-' || p_notification_id::text,
                    'data', jsonb_build_object(
                        'notification_id', p_notification_id,
                        'url', '/notifications',
                        'created_at', notification_rec.created_at,
                        'sender', COALESCE(notification_rec.created_by_name, notification_rec.created_by, 'System'),
                        'type', notification_rec.type,
                        'priority', notification_rec.priority
                    )
                )
            );
            
            queued_count := queued_count + 1;
        END LOOP;
    END LOOP;
    
    RETURN 'Queued ' || queued_count || ' push notifications for notification ' || p_notification_id;
END;
$$;

-- Create the trigger function
CREATE OR REPLACE FUNCTION trigger_queue_push_notifications()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Only queue for new notifications (INSERT)
    IF TG_OP = 'INSERT' THEN
        -- Call the queue function for the new notification
        PERFORM queue_push_notification(NEW.id);
        RETURN NEW;
    END IF;
    
    RETURN NULL;
END;
$$;

-- Create ONE trigger (not three!)
CREATE TRIGGER trigger_queue_push_notifications
    AFTER INSERT ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION trigger_queue_push_notifications();

-- Verify the setup
SELECT 
    trigger_name,
    event_manipulation,
    action_timing
FROM information_schema.triggers 
WHERE event_object_table = 'notifications'
ORDER BY trigger_name;