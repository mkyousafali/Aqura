-- Migration: Fix queue_push_notification function to properly map notifications to devices
-- This ensures push notifications are linked to specific user devices/subscriptions
-- Uses notification_recipients table with delivery_status tracking

-- Drop triggers first before dropping functions (to avoid dependency errors)
DROP TRIGGER IF EXISTS trigger_queue_push_notification ON notifications;
DROP TRIGGER IF EXISTS trigger_update_delivery_status ON notification_queue;

-- Now drop the functions
DROP FUNCTION IF EXISTS queue_push_notification(uuid);
DROP FUNCTION IF EXISTS queue_push_notification_trigger();
DROP FUNCTION IF EXISTS update_notification_delivery_status();

-- Create the improved function that creates one queue entry per active device
-- Now uses notification_recipients table with delivery_status = 'pending'
CREATE OR REPLACE FUNCTION queue_push_notification(p_notification_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_notification record;
    v_recipient record;
    v_subscription record;
BEGIN
    -- Get the notification details
    SELECT * INTO v_notification
    FROM notifications
    WHERE id = p_notification_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Notification % not found', p_notification_id;
    END IF;

    -- For each pending recipient, create queue entries for their active devices
    FOR v_recipient IN
        SELECT 
            id as recipient_id,
            user_id,
            notification_id
        FROM notification_recipients
        WHERE notification_id = p_notification_id
        AND delivery_status = 'pending'
    LOOP
        -- Get all active push subscriptions for this recipient's user
        FOR v_subscription IN
            SELECT 
                id as subscription_id,
                device_id,
                endpoint,
                p256dh,
                auth
            FROM push_subscriptions
            WHERE user_id = v_recipient.user_id
            AND is_active = true
        LOOP
            -- Create a queue entry for each active device
            INSERT INTO notification_queue (
                notification_id,
                user_id,
                device_id,
                push_subscription_id,
                status,
                payload,
                scheduled_at
            )
            VALUES (
                p_notification_id,
                v_recipient.user_id,
                v_subscription.device_id,
                v_subscription.subscription_id,
                'pending',
                jsonb_build_object(
                    'title', v_notification.title,
                    'body', v_notification.message,
                    'icon', '/favicon.ico',
                    'badge', '/favicon.ico',
                    'data', jsonb_build_object(
                        'notificationId', p_notification_id,
                        'recipientId', v_recipient.recipient_id,
                        'type', v_notification.type,
                        'url', '/mobile'
                    )
                ),
                NOW()
            );
        END LOOP;
    END LOOP;

    RAISE NOTICE 'Queued push notifications for notification %', p_notification_id;
END;
$$;

-- Add comment explaining the function
COMMENT ON FUNCTION queue_push_notification(uuid) IS 
'Queues push notifications for delivery by creating one queue entry per active user device. Can be called manually or by trigger.';

-- Create trigger function wrapper (triggers cannot take parameters)
CREATE OR REPLACE FUNCTION queue_push_notification_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    PERFORM queue_push_notification(NEW.id);
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION queue_push_notification_trigger() IS 
'Trigger wrapper function that calls queue_push_notification with the new notification ID.';

-- Create function to update delivery status when push notification is sent
CREATE OR REPLACE FUNCTION update_notification_delivery_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- When a notification_queue item is marked as 'sent', update the recipient's delivery status
    IF NEW.status = 'sent' AND OLD.status != 'sent' THEN
        UPDATE notification_recipients
        SET 
            delivery_status = 'delivered',
            delivery_attempted_at = NEW.sent_at,
            updated_at = NOW()
        WHERE notification_id = NEW.notification_id
        AND user_id = NEW.user_id;
        
        RAISE NOTICE 'Updated delivery status for notification % user %', NEW.notification_id, NEW.user_id;
    
    -- When a notification_queue item is marked as 'failed', update the recipient's delivery status
    ELSIF NEW.status = 'failed' AND OLD.status != 'failed' THEN
        UPDATE notification_recipients
        SET 
            delivery_status = 'failed',
            delivery_attempted_at = NEW.last_attempt_at,
            error_message = NEW.error_message,
            updated_at = NOW()
        WHERE notification_id = NEW.notification_id
        AND user_id = NEW.user_id;
        
        RAISE NOTICE 'Marked delivery as failed for notification % user %', NEW.notification_id, NEW.user_id;
    END IF;
    
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION update_notification_delivery_status() IS 
'Updates notification_recipients.delivery_status when push notifications are sent or failed.';

-- Recreate the triggers (order matters: create functions first, then triggers)
CREATE TRIGGER trigger_queue_push_notification
    AFTER INSERT ON notifications
    FOR EACH ROW
    WHEN (NEW.status IN ('unread', 'published'))
    EXECUTE PROCEDURE queue_push_notification_trigger();

COMMENT ON TRIGGER trigger_queue_push_notification ON notifications IS 
'Automatically queues push notifications when new notifications are inserted with unread or published status.';

-- Create trigger to update delivery status when queue item status changes
CREATE TRIGGER trigger_update_delivery_status
    AFTER UPDATE OF status ON notification_queue
    FOR EACH ROW
    WHEN (NEW.status IN ('sent', 'failed'))
    EXECUTE PROCEDURE update_notification_delivery_status();

COMMENT ON TRIGGER trigger_update_delivery_status ON notification_queue IS 
'Automatically updates notification_recipients.delivery_status when push notifications are sent or failed.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION queue_push_notification(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION queue_push_notification(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION queue_push_notification_trigger() TO authenticated;
GRANT EXECUTE ON FUNCTION queue_push_notification_trigger() TO service_role;
GRANT EXECUTE ON FUNCTION update_notification_delivery_status() TO authenticated;
GRANT EXECUTE ON FUNCTION update_notification_delivery_status() TO service_role;

-- ============================================================================
-- POST-MIGRATION: Manually queue existing notifications that were not queued
-- ============================================================================
-- This section will queue all existing notifications that have recipients
-- with pending delivery_status but no queue entries

-- Note: This is a one-time operation to catch up on missed notifications
-- Uncomment and run the following if you want to queue ALL pending notifications:

/*
DO $$
DECLARE
    v_notification_id uuid;
    v_queued_count integer := 0;
BEGIN
    -- Find all notifications that have pending recipients but no queue entries
    FOR v_notification_id IN
        SELECT DISTINCT nr.notification_id
        FROM notification_recipients nr
        LEFT JOIN notification_queue nq ON nr.notification_id = nq.notification_id
        WHERE nr.delivery_status = 'pending'
        AND nq.id IS NULL
    LOOP
        -- Queue each notification
        PERFORM queue_push_notification(v_notification_id);
        v_queued_count := v_queued_count + 1;
    END LOOP;
    
    RAISE NOTICE 'Queued % existing notifications with pending recipients', v_queued_count;
END $$;
*/
