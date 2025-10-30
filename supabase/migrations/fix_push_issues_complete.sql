-- ============================================================
-- FIX PUSH NOTIFICATION ISSUES
-- ============================================================
-- Issue 1: Push received 3 times (duplicate triggers)
-- Issue 2: Push not working when phone is locked
-- ============================================================

-- PART 1: FIX DUPLICATE TRIGGERS
-- ============================================================

-- Drop ALL existing push notification triggers
DROP TRIGGER IF EXISTS trigger_queue_push_notification ON notifications;
DROP TRIGGER IF EXISTS trigger_queue_push_notifications ON notifications;
DROP TRIGGER IF EXISTS trigger_queue_quick_task_push_notifications ON notifications;

-- Recreate ONLY ONE trigger with proper conditions
CREATE TRIGGER trigger_queue_push_notification
    AFTER INSERT ON notifications
    FOR EACH ROW
    WHEN (NEW.status = 'published')
    EXECUTE FUNCTION queue_push_notification_trigger();

-- Verify only one trigger exists
SELECT 
    '✅ Trigger fixed - should show only 1 trigger' as status,
    tgname as trigger_name,
    tgrelid::regclass as table_name
FROM pg_trigger
WHERE tgrelid = 'notifications'::regclass
AND tgname LIKE '%push%';

-- ============================================================
-- PART 2: ENHANCE FOR LOCKED PHONE SUPPORT
-- ============================================================

-- Update notification_queue table to include renotification_at
-- This helps retry failed notifications
ALTER TABLE notification_queue 
ADD COLUMN IF NOT EXISTS renotification_at timestamptz;

-- Add index for efficient renotification queries
CREATE INDEX IF NOT EXISTS idx_notification_queue_renotify 
ON notification_queue (renotification_at) 
WHERE status IN ('failed', 'retry');

-- Create function to handle failed notifications on locked phones
CREATE OR REPLACE FUNCTION schedule_renotification()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- If notification failed and error indicates locked/background issue
    IF NEW.status = 'failed' AND 
       (NEW.error_message ILIKE '%background%' OR 
        NEW.error_message ILIKE '%locked%' OR
        NEW.error_message ILIKE '%inactive%') THEN
        
        -- Schedule renotification in 5 minutes
        NEW.renotification_at := NOW() + INTERVAL '5 minutes';
        NEW.status := 'retry';
        NEW.retry_count := COALESCE(NEW.retry_count, 0) + 1;
        
        -- Don't retry more than 5 times
        IF NEW.retry_count >= 5 THEN
            NEW.status := 'failed';
            NEW.renotification_at := NULL;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Create trigger for automatic renotification scheduling
DROP TRIGGER IF EXISTS trigger_schedule_renotification ON notification_queue;
CREATE TRIGGER trigger_schedule_renotification
    BEFORE UPDATE ON notification_queue
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'failed')
    EXECUTE FUNCTION schedule_renotification();

-- ============================================================
-- PART 3: ADD HIGH PRIORITY FLAG FOR IMPORTANT NOTIFICATIONS
-- ============================================================

-- Add priority column to notification_queue if not exists
ALTER TABLE notification_queue
ADD COLUMN IF NOT EXISTS notification_priority text DEFAULT 'normal';

-- Create index for priority
CREATE INDEX IF NOT EXISTS idx_notification_queue_priority 
ON notification_queue (notification_priority, status);

-- Update the queue_push_notification function to include priority
CREATE OR REPLACE FUNCTION queue_push_notification(p_notification_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_notification record;
    v_recipient record;
    v_subscription record;
    v_priority text;
BEGIN
    -- Get the notification details
    SELECT * INTO v_notification
    FROM notifications
    WHERE id = p_notification_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Notification % not found', p_notification_id;
    END IF;

    -- Determine priority
    v_priority := COALESCE(v_notification.priority, 'medium');

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
                notification_priority,
                payload,
                scheduled_at
            )
            VALUES (
                p_notification_id,
                v_recipient.user_id,
                v_subscription.device_id,
                v_subscription.subscription_id,
                'pending',
                v_priority,
                jsonb_build_object(
                    'title', v_notification.title,
                    'body', v_notification.message,
                    'icon', '/icons/icon-192x192.png',
                    'badge', '/icons/icon-96x96.png',
                    'tag', 'aqura-' || p_notification_id::text,
                    'requireInteraction', CASE 
                        WHEN v_priority IN ('high', 'urgent') THEN true 
                        ELSE false 
                    END,
                    'silent', false,
                    'vibrate', CASE 
                        WHEN v_priority = 'urgent' THEN ARRAY[300, 100, 300, 100, 300]
                        WHEN v_priority = 'high' THEN ARRAY[200, 100, 200, 100, 200]
                        ELSE ARRAY[200, 100, 200]
                    END,
                    'data', jsonb_build_object(
                        'notificationId', p_notification_id,
                        'recipientId', v_recipient.recipient_id,
                        'type', v_notification.type,
                        'priority', v_priority,
                        'timestamp', EXTRACT(EPOCH FROM NOW()),
                        'url', '/mobile'
                    )
                ),
                NOW()
            );
        END LOOP;
    END LOOP;

    RAISE NOTICE 'Queued push notifications for notification % with priority %', p_notification_id, v_priority;
END;
$$;

-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================

-- 1. Check triggers (should be only 1)
SELECT 
    '1️⃣ Trigger Check' as test,
    COUNT(*) as trigger_count,
    CASE 
        WHEN COUNT(*) = 1 THEN '✅ PASS - Only 1 trigger'
        ELSE '❌ FAIL - Multiple triggers found'
    END as result
FROM pg_trigger
WHERE tgrelid = 'notifications'::regclass
AND tgname LIKE '%push%';

-- 2. Check renotification column exists
SELECT 
    '2️⃣ Renotification Column' as test,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'notification_queue' 
            AND column_name = 'renotification_at'
        ) THEN '✅ PASS - Column exists'
        ELSE '❌ FAIL - Column missing'
    END as result;

-- 3. Check priority column exists
SELECT 
    '3️⃣ Priority Column' as test,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'notification_queue' 
            AND column_name = 'notification_priority'
        ) THEN '✅ PASS - Column exists'
        ELSE '❌ FAIL - Column missing'
    END as result;

-- 4. Test notification creation (uncomment to test)
/*
INSERT INTO notifications (
    title, 
    message, 
    target_users, 
    target_type, 
    type, 
    priority, 
    status,
    created_by,
    created_by_name,
    created_by_role
) VALUES (
    'Test After Fix',
    'This should create ONLY 1 queue entry',
    ARRAY['b658eca1-3cc1-48b2-bd3c-33b81fab5a0f']::uuid[],
    'specific_users',
    'info',
    'high',
    'published',
    'system',
    'System Test',
    'Admin'
) RETURNING id;

-- Then check queue count (should be 1):
-- SELECT COUNT(*) FROM notification_queue WHERE notification_id = '<id from above>';
*/

-- ============================================================
-- NOTES FOR FRONTEND CHANGES NEEDED
-- ============================================================
/*
To fix "not working when phone is locked":

1. Service Worker needs to handle push events even when app is closed
   - Already implemented in sw-push.js ✅
   
2. Ensure requireInteraction is set for high priority notifications
   - Updated in queue_push_notification function above ✅
   
3. Edge Function should set proper urgency header:
   - Add to Edge Function: urgency: 'high' for FCM
   
4. Test on actual device with:
   - Phone locked
   - App closed completely
   - Background refresh enabled
   
5. For iOS: Ensure web app is "Add to Home Screen" 
   - iOS only supports push when installed as PWA
*/
