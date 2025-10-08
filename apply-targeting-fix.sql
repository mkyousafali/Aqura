-- Apply the corrected queue_push_notification function that handles targeting

-- Drop the existing function
DROP FUNCTION IF EXISTS queue_push_notification(UUID);

-- Create the updated function with proper targeting support
CREATE OR REPLACE FUNCTION queue_push_notification(
    p_notification_id UUID
)
RETURNS TEXT AS $$
DECLARE
    user_record RECORD;
    subscription_record RECORD;
    notification_data RECORD;
    total_queued INTEGER := 0;
BEGIN
    -- Get notification data
    SELECT 
        title,
        message as body,
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
                  AND ps.is_active = true
            LOOP
                -- Create the payload
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
            
        WHEN 'specific_users' THEN
            -- Queue for specific users from target_users array
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
                      AND ps.is_active = true
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
            
        ELSE
            -- For other target types (role_based, branch_based), implement as needed
            -- For now, default to all users
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
                  AND ps.is_active = true
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
            
    END CASE;
    
    RETURN 'Queued ' || total_queued || ' push notifications for notification ' || p_notification_id::text;
END;
$$ LANGUAGE plpgsql;

SELECT 'Updated queue_push_notification function successfully' as result;