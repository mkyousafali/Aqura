-- Complete cleanup and fresh installation of notification push trigger
-- This script completely cleans all existing functions and recreates everything fresh

-- Step 1: Drop ALL triggers and functions completely
DROP TRIGGER IF EXISTS trigger_queue_push_notification ON notifications CASCADE;
DROP TRIGGER IF EXISTS trigger_notification_push_queue ON notifications CASCADE;

-- Aggressively drop all function versions
DROP FUNCTION IF EXISTS queue_push_notification CASCADE;
DROP FUNCTION IF EXISTS trigger_queue_push_notification CASCADE;

-- Clear any remaining function signatures
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT oid::regprocedure FROM pg_proc WHERE proname = 'queue_push_notification') LOOP
        EXECUTE 'DROP FUNCTION ' || r.oid::regprocedure || ' CASCADE';
    END LOOP;
    
    FOR r IN (SELECT oid::regprocedure FROM pg_proc WHERE proname = 'trigger_queue_push_notification') LOOP
        EXECUTE 'DROP FUNCTION ' || r.oid::regprocedure || ' CASCADE';
    END LOOP;
END
$$;

-- Step 2: Create fresh queue_push_notification function
CREATE FUNCTION queue_push_notification(p_notification_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    notification_record RECORD;
    subscription_record RECORD;
    queue_entry_id UUID;
BEGIN
    -- Get notification details
    SELECT * INTO notification_record
    FROM notifications 
    WHERE id = p_notification_id AND status = 'published';
    
    IF NOT FOUND THEN
        RAISE NOTICE 'Notification % not found or not published', p_notification_id;
        RETURN;
    END IF;
    
    RAISE NOTICE 'Processing notification: % (title: %)', 
        p_notification_id, notification_record.title;
    
    -- Handle different target types
    IF notification_record.target_type = 'all_users' THEN
        -- Queue for all users with active push subscriptions
        FOR subscription_record IN 
            SELECT ps.*, u.username
            FROM push_subscriptions ps
            INNER JOIN users u ON ps.user_id = u.id
            WHERE ps.is_active = true
            AND ps.last_seen > NOW() - INTERVAL '7 days'
            AND u.status = 'active'
        LOOP
            -- Create queue entry
            queue_entry_id := gen_random_uuid();
            
            INSERT INTO notification_queue (
                id,
                notification_id,
                user_id,
                device_id,
                push_subscription_id,
                status,
                payload,
                created_at
            ) VALUES (
                queue_entry_id,
                p_notification_id,
                subscription_record.user_id,
                subscription_record.device_id,
                subscription_record.id,
                'pending',
                jsonb_build_object(
                    'title', notification_record.title,
                    'body', notification_record.message,
                    'icon', '/favicon.png',
                    'badge', '/badge-icon.png',
                    'data', jsonb_build_object(
                        'notification_id', p_notification_id,
                        'type', notification_record.type,
                        'priority', notification_record.priority,
                        'url', '/notifications'
                    )
                ),
                NOW()
            );
            
            RAISE NOTICE 'Queued notification for user % device %', subscription_record.username, subscription_record.device_id;
        END LOOP;
    ELSE
        -- Handle specific user targeting using target_users JSONB field
        FOR subscription_record IN 
            SELECT ps.*, u.username, target_user_id::text
            FROM notifications n,
                 jsonb_array_elements_text(n.target_users) AS target_user_id
            INNER JOIN push_subscriptions ps ON ps.user_id::text = target_user_id::text
            INNER JOIN users u ON ps.user_id = u.id
            WHERE n.id = p_notification_id
            AND ps.is_active = true
            AND ps.last_seen > NOW() - INTERVAL '7 days'
        LOOP
            -- Create queue entry
            queue_entry_id := gen_random_uuid();
            
            INSERT INTO notification_queue (
                id,
                notification_id,
                user_id,
                device_id,
                push_subscription_id,
                status,
                payload,
                created_at
            ) VALUES (
                queue_entry_id,
                p_notification_id,
                subscription_record.user_id,
                subscription_record.device_id,
                subscription_record.id,
                'pending',
                jsonb_build_object(
                    'title', notification_record.title,
                    'body', notification_record.message,
                    'icon', '/favicon.png',
                    'badge', '/badge-icon.png',
                    'data', jsonb_build_object(
                        'notification_id', p_notification_id,
                        'type', notification_record.type,
                        'priority', notification_record.priority,
                        'url', '/notifications'
                    )
                ),
                NOW()
            );
            
            RAISE NOTICE 'Queued notification for user % device %', subscription_record.username, subscription_record.device_id;
        END LOOP;
    END IF;
    
    RAISE NOTICE 'Completed queuing for notification %', p_notification_id;
END;
$$;

-- Step 3: Create fresh trigger function
CREATE FUNCTION trigger_queue_push_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Only queue if notification is being set to published status
    IF NEW.status = 'published' AND (TG_OP = 'INSERT' OR OLD.status != 'published') THEN
        RAISE NOTICE 'Trigger fired for notification: % (%), calling queue function...', NEW.title, NEW.id;
        
        -- Call the queue function
        PERFORM queue_push_notification(NEW.id);
        
        RAISE NOTICE 'Queue function completed for notification: %', NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Step 4: Create the trigger
CREATE TRIGGER trigger_queue_push_notification
    AFTER INSERT OR UPDATE ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION trigger_queue_push_notification();

-- Step 5: Test with explicit UUID casting
SELECT queue_push_notification('2e2d676a-dc2c-4770-9784-bf0dc1b3bbdd'::UUID);

-- Step 6: Check results
SELECT 
    nq.id,
    nq.notification_id,
    nq.status,
    n.title,
    n.message,
    u.username
FROM notification_queue nq
JOIN notifications n ON nq.notification_id = n.id
JOIN users u ON nq.user_id = u.id
WHERE nq.notification_id = '2e2d676a-dc2c-4770-9784-bf0dc1b3bbdd'
ORDER BY nq.created_at DESC;