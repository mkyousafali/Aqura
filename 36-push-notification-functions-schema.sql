-- Push Notification Functions Schema
-- This file contains database functions for handling push notification queuing

-- Function to queue push notifications for delivery
CREATE OR REPLACE FUNCTION queue_push_notification(
    p_notification_id UUID,
    p_user_id UUID DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    notification_record RECORD;
    subscription_record RECORD;
    target_user_id TEXT;
    payload JSONB;
BEGIN
    -- Get notification details
    SELECT n.*, u.username
    INTO notification_record
    FROM notifications n
    LEFT JOIN users u ON u.id::text = n.created_by
    WHERE n.id = p_notification_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Notification not found: %', p_notification_id;
    END IF;
    
    -- Build notification payload
    payload := jsonb_build_object(
        'title', notification_record.title,
        'body', notification_record.message,
        'icon', '/favicon.png',
        'badge', '/badge-icon.png',
        'data', jsonb_build_object(
            'notification_id', notification_record.id,
            'url', '/notifications?id=' || notification_record.id,
            'created_at', notification_record.created_at,
            'sender', COALESCE(notification_record.username, notification_record.created_by_name)
        )
    );
    
    -- Queue for specific user if provided
    IF p_user_id IS NOT NULL THEN
        -- Get active push subscriptions for the user
        FOR subscription_record IN
            SELECT ps.*
            FROM push_subscriptions ps
            WHERE ps.user_id = p_user_id
            AND ps.is_active = true
            AND ps.last_seen > NOW() - INTERVAL '7 days'
        LOOP
            INSERT INTO notification_queue (
                notification_id,
                user_id,
                device_id,
                push_subscription_id,
                payload
            ) VALUES (
                p_notification_id,
                p_user_id,
                subscription_record.device_id,
                subscription_record.id,
                payload
            );
        END LOOP;
    ELSE
        -- Check target type and queue accordingly
        IF notification_record.target_type = 'all_users' THEN
            -- Queue for all active users
            FOR subscription_record IN
                SELECT ps.*, u.id as user_id
                FROM push_subscriptions ps
                JOIN users u ON ps.user_id = u.id
                WHERE ps.is_active = true
                AND ps.last_seen > NOW() - INTERVAL '7 days'
                AND u.status = 'active'
            LOOP
                INSERT INTO notification_queue (
                    notification_id,
                    user_id,
                    device_id,
                    push_subscription_id,
                    payload
                ) VALUES (
                    p_notification_id,
                    subscription_record.user_id,
                    subscription_record.device_id,
                    subscription_record.id,
                    payload
                );
            END LOOP;
        ELSIF notification_record.target_type = 'specific_users' AND notification_record.target_users IS NOT NULL THEN
            -- Queue for specific users from target_users JSONB array
            FOR target_user_id IN 
                SELECT jsonb_array_elements_text(notification_record.target_users)
            LOOP
                FOR subscription_record IN
                    SELECT ps.*
                    FROM push_subscriptions ps
                    JOIN users u ON ps.user_id = u.id
                    WHERE u.id::text = target_user_id
                    AND ps.is_active = true
                    AND ps.last_seen > NOW() - INTERVAL '7 days'
                    AND u.status = 'active'
                LOOP
                    INSERT INTO notification_queue (
                        notification_id,
                        user_id,
                        device_id,
                        push_subscription_id,
                        payload
                    ) VALUES (
                        p_notification_id,
                        subscription_record.user_id,
                        subscription_record.device_id,
                        subscription_record.id,
                        payload
                    );
                END LOOP;
            END LOOP;
        -- Add support for other target types (roles, branches) if needed
        ELSIF notification_record.target_type = 'specific_roles' AND notification_record.target_roles IS NOT NULL THEN
            -- Queue for users with specific roles
            FOR subscription_record IN
                SELECT ps.*, u.id as user_id
                FROM push_subscriptions ps
                JOIN users u ON ps.user_id = u.id
                JOIN user_roles ur ON u.role_id = ur.id
                WHERE jsonb_exists(notification_record.target_roles, ur.role_code)
                AND ps.is_active = true
                AND ps.last_seen > NOW() - INTERVAL '7 days'
                AND u.status = 'active'
            LOOP
                INSERT INTO notification_queue (
                    notification_id,
                    user_id,
                    device_id,
                    push_subscription_id,
                    payload
                ) VALUES (
                    p_notification_id,
                    subscription_record.user_id,
                    subscription_record.device_id,
                    subscription_record.id,
                    payload
                );
            END LOOP;
        ELSIF notification_record.target_type = 'specific_branches' AND notification_record.target_branches IS NOT NULL THEN
            -- Queue for users in specific branches
            FOR subscription_record IN
                SELECT ps.*, u.id as user_id
                FROM push_subscriptions ps
                JOIN users u ON ps.user_id = u.id
                WHERE jsonb_exists(notification_record.target_branches, u.branch_id::text)
                AND ps.is_active = true
                AND ps.last_seen > NOW() - INTERVAL '7 days'
                AND u.status = 'active'
            LOOP
                INSERT INTO notification_queue (
                    notification_id,
                    user_id,
                    device_id,
                    push_subscription_id,
                    payload
                ) VALUES (
                    p_notification_id,
                    subscription_record.user_id,
                    subscription_record.device_id,
                    subscription_record.id,
                    payload
                );
            END LOOP;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function for the trigger
CREATE OR REPLACE FUNCTION trigger_queue_push_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Queue push notification for delivery
    PERFORM queue_push_notification(NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;