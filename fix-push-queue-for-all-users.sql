-- Fix push notification queue to work with users who don't have push subscriptions
-- Currently only 4 out of 82 users have push subscriptions, so most notifications aren't being queued

-- Create a modified queue_push_notification function that:
-- 1. Creates queue entries for users WITH push subscriptions (existing behavior)
-- 2. Creates placeholder queue entries for users WITHOUT push subscriptions (new behavior)
-- This allows the push notification processor to work for all users

DROP FUNCTION IF EXISTS queue_push_notification(uuid);

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
    recipients_count integer := 0;
BEGIN
    -- Get notification details
    SELECT * INTO notification_rec 
    FROM notifications 
    WHERE id = p_notification_id;
    
    IF notification_rec IS NULL THEN
        RETURN 'Notification not found';
    END IF;
    
    -- Process based on target_type to populate notification_recipients
    CASE notification_rec.target_type
        
        WHEN 'all_users' THEN
            -- Add all active users to notification_recipients
            FOR user_rec IN 
                SELECT DISTINCT u.id, u.username
                FROM users u
                WHERE u.status = 'active'
            LOOP
                INSERT INTO notification_recipients (
                    notification_id,
                    user_id
                ) VALUES (
                    p_notification_id,
                    user_rec.id
                ) ON CONFLICT (notification_id, user_id) DO NOTHING;
                
                recipients_count := recipients_count + 1;
                
                -- Now queue push notifications for this user
                -- Check if user has active push subscriptions
                IF EXISTS (
                    SELECT 1 FROM push_subscriptions 
                    WHERE user_id = user_rec.id AND is_active = true
                ) THEN
                    -- User has push subscriptions - create entries for each device
                    FOR device_rec IN
                        SELECT id, device_id, endpoint, p256dh, auth
                        FROM push_subscriptions 
                        WHERE user_id = user_rec.id 
                        AND is_active = true
                    LOOP
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
                                'body', notification_rec.message,
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
                ELSE
                    -- User doesn't have push subscriptions - create a placeholder entry
                    -- This allows the processor to handle in-app notifications
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
                        'web-browser-' || user_rec.id::text,
                        NULL, -- No push subscription
                        'pending',
                        jsonb_build_object(
                            'title', notification_rec.title,
                            'body', notification_rec.message,
                            'icon', '/icons/icon-192x192.png',
                            'badge', '/icons/icon-96x96.png',
                            'tag', 'aqura-notification-' || p_notification_id::text,
                            'data', jsonb_build_object(
                                'notification_id', p_notification_id,
                                'url', '/notifications',
                                'created_at', notification_rec.created_at,
                                'sender', COALESCE(notification_rec.created_by_name, notification_rec.created_by, 'System'),
                                'type', notification_rec.type,
                                'priority', notification_rec.priority,
                                'in_app_only', true -- Flag to indicate this is for in-app notifications only
                            )
                        )
                    );
                    
                    queued_count := queued_count + 1;
                END IF;
            END LOOP;
            
        WHEN 'specific_users' THEN
            -- Add specific users from target_users JSONB array
            IF notification_rec.target_users IS NOT NULL THEN
                FOR user_rec IN 
                    SELECT u.id, u.username
                    FROM users u
                    WHERE u.id = ANY(
                        SELECT (jsonb_array_elements_text(notification_rec.target_users))::uuid
                    )
                    AND u.status = 'active'
                LOOP
                    INSERT INTO notification_recipients (
                        notification_id,
                        user_id
                    ) VALUES (
                        p_notification_id,
                        user_rec.id
                    ) ON CONFLICT (notification_id, user_id) DO NOTHING;
                    
                    recipients_count := recipients_count + 1;
                    
                    -- Same logic as above for push notifications vs placeholders
                    IF EXISTS (
                        SELECT 1 FROM push_subscriptions 
                        WHERE user_id = user_rec.id AND is_active = true
                    ) THEN
                        FOR device_rec IN
                            SELECT id, device_id, endpoint, p256dh, auth
                            FROM push_subscriptions 
                            WHERE user_id = user_rec.id 
                            AND is_active = true
                        LOOP
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
                                    'body', notification_rec.message,
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
                    ELSE
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
                            'web-browser-' || user_rec.id::text,
                            NULL,
                            'pending',
                            jsonb_build_object(
                                'title', notification_rec.title,
                                'body', notification_rec.message,
                                'icon', '/icons/icon-192x192.png',
                                'badge', '/icons/icon-96x96.png',
                                'tag', 'aqura-notification-' || p_notification_id::text,
                                'data', jsonb_build_object(
                                    'notification_id', p_notification_id,
                                    'url', '/notifications',
                                    'created_at', notification_rec.created_at,
                                    'sender', COALESCE(notification_rec.created_by_name, notification_rec.created_by, 'System'),
                                    'type', notification_rec.type,
                                    'priority', notification_rec.priority,
                                    'in_app_only', true
                                )
                            )
                        );
                        
                        queued_count := queued_count + 1;
                    END IF;
                END LOOP;
            END IF;
            
        -- Add other target types as needed...
        
        ELSE
            RETURN 'Unknown target_type: ' || notification_rec.target_type;
    END CASE;
    
    -- Update the notification with recipient count
    UPDATE notifications 
    SET total_recipients = recipients_count,
        updated_at = NOW()
    WHERE id = p_notification_id;
    
    RETURN 'Added ' || recipients_count || ' recipients and queued ' || queued_count || ' notifications for delivery (type: ' || notification_rec.target_type || ')';
END;
$$;

-- Success message
SELECT 'Enhanced queue_push_notification function created!' as status;
SELECT 'Now creates queue entries for ALL users, not just those with push subscriptions' as improvement;
SELECT 'Users without push subscriptions get placeholder entries for in-app notifications' as feature;