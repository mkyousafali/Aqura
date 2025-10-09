-- Fix notification targeting issue
-- Problem: notifications sent to specific users are being received by all users
-- Root causes:
-- 1. queue_push_notification function ignores targeting and sends to ALL users
-- 2. notification_recipients table is not being populated
-- 3. Frontend listeners use wrong targeting logic

-- ================================================================
-- 1. Fix the queue_push_notification function to respect targeting
-- ================================================================

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
    target_user_id text;
    target_role text;
    target_branch_id text;
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
    
    -- Process based on target_type
    CASE notification_rec.target_type
        
        WHEN 'all_users' THEN
            -- Queue for all active users
            FOR user_rec IN 
                SELECT DISTINCT u.id, u.username
                FROM users u
                WHERE u.status = 'active'
            LOOP
                -- Insert into notification_recipients
                INSERT INTO notification_recipients (
                    notification_id,
                    user_id,
                    role,
                    branch_id
                ) VALUES (
                    p_notification_id,
                    user_rec.id,
                    NULL,
                    NULL
                ) ON CONFLICT (notification_id, user_id) DO NOTHING;
                
                recipients_count := recipients_count + 1;
                
                -- Queue push notifications for this user's devices
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
                                'created_at', notification_rec.created_at
                            )
                        )
                    );
                    
                    queued_count := queued_count + 1;
                END LOOP;
            END LOOP;
            
        WHEN 'specific_users' THEN
            -- Queue for specific users from target_users JSONB array
            IF notification_rec.target_users IS NOT NULL THEN
                FOR target_user_id IN 
                    SELECT jsonb_array_elements_text(notification_rec.target_users)
                LOOP
                    -- Find user by ID
                    SELECT u.id, u.username INTO user_rec
                    FROM users u
                    WHERE u.id = target_user_id::uuid
                      AND u.status = 'active';
                    
                    IF user_rec.id IS NOT NULL THEN
                        -- Insert into notification_recipients
                        INSERT INTO notification_recipients (
                            notification_id,
                            user_id
                        ) VALUES (
                            p_notification_id,
                            user_rec.id
                        ) ON CONFLICT (notification_id, user_id) DO NOTHING;
                        
                        recipients_count := recipients_count + 1;
                        
                        -- Queue push notifications for this user's devices
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
                                        'created_at', notification_rec.created_at
                                    )
                                )
                            );
                            
                            queued_count := queued_count + 1;
                        END LOOP;
                    END IF;
                END LOOP;
            END IF;
            
        WHEN 'specific_roles' THEN
            -- Queue for users with specific roles
            IF notification_rec.target_roles IS NOT NULL THEN
                FOR target_role IN 
                    SELECT jsonb_array_elements_text(notification_rec.target_roles)
                LOOP
                    FOR user_rec IN 
                        SELECT DISTINCT u.id, u.username
                        FROM users u
                        JOIN user_roles ur ON u.role_id = ur.id
                        WHERE ur.role_code = target_role
                          AND u.status = 'active'
                    LOOP
                        -- Insert into notification_recipients
                        INSERT INTO notification_recipients (
                            notification_id,
                            user_id,
                            role
                        ) VALUES (
                            p_notification_id,
                            user_rec.id,
                            target_role
                        ) ON CONFLICT (notification_id, user_id) DO NOTHING;
                        
                        recipients_count := recipients_count + 1;
                        
                        -- Queue push notifications for this user's devices
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
                                        'created_at', notification_rec.created_at
                                    )
                                )
                            );
                            
                            queued_count := queued_count + 1;
                        END LOOP;
                    END LOOP;
                END LOOP;
            END IF;
            
        WHEN 'specific_branches' THEN
            -- Queue for users in specific branches
            IF notification_rec.target_branches IS NOT NULL THEN
                FOR target_branch_id IN 
                    SELECT jsonb_array_elements_text(notification_rec.target_branches)
                LOOP
                    FOR user_rec IN 
                        SELECT DISTINCT u.id, u.username
                        FROM users u
                        WHERE u.branch_id = target_branch_id::uuid
                          AND u.status = 'active'
                    LOOP
                        -- Insert into notification_recipients
                        INSERT INTO notification_recipients (
                            notification_id,
                            user_id,
                            branch_id
                        ) VALUES (
                            p_notification_id,
                            user_rec.id,
                            target_branch_id
                        ) ON CONFLICT (notification_id, user_id) DO NOTHING;
                        
                        recipients_count := recipients_count + 1;
                        
                        -- Queue push notifications for this user's devices
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
                                        'created_at', notification_rec.created_at
                                    )
                                )
                            );
                            
                            queued_count := queued_count + 1;
                        END LOOP;
                    END LOOP;
                END LOOP;
            END IF;
            
        ELSE
            RETURN 'Unknown target_type: ' || notification_rec.target_type;
    END CASE;
    
    -- Update the notification with recipient count
    UPDATE notifications 
    SET total_recipients = recipients_count,
        updated_at = NOW()
    WHERE id = p_notification_id;
    
    RETURN 'Queued ' || queued_count || ' push notifications for ' || recipients_count || ' recipients (notification ' || p_notification_id || ', type: ' || notification_rec.target_type || ')';
END;
$$;

-- ================================================================
-- 2. Test the fix with different targeting scenarios
-- ================================================================

-- Verify the function was created successfully
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines 
WHERE routine_name = 'queue_push_notification';

-- Check current notifications and their targeting
SELECT 
    id,
    title,
    target_type,
    target_users,
    target_roles,
    target_branches,
    total_recipients
FROM notifications 
ORDER BY created_at DESC 
LIMIT 5;

-- Check notification_recipients population
SELECT 
    COUNT(*) as total_recipients,
    COUNT(DISTINCT notification_id) as notifications_with_recipients,
    COUNT(DISTINCT user_id) as unique_users
FROM notification_recipients;

-- ================================================================
-- 3. Instructions for manual application
-- ================================================================

-- This script fixes the core targeting issue by:
-- 1. Replacing the queue_push_notification function to respect target_type
-- 2. Properly populating notification_recipients table for each target type
-- 3. Maintaining both push queue AND recipient tracking
-- 
-- After applying this SQL:
-- 1. Test creating notifications with different target types
-- 2. Verify notification_recipients table is populated correctly  
-- 3. Check that real-time listeners only notify intended users
-- 4. Verify frontend changes work with notification_recipients table

SELECT 'Notification targeting fix applied successfully!' as status;