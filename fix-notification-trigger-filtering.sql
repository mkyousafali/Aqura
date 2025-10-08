-- Fix notification trigger filtering issue
-- The problem is that the trigger is filtering notification types
-- Test notifications work but real notifications don't reach other users

-- First, check what triggers currently exist
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'notifications'
ORDER BY trigger_name;

-- Check what notification types exist in the database
SELECT DISTINCT type, COUNT(*) as count
FROM notifications 
GROUP BY type
ORDER BY count DESC;

-- Check recent notifications and their processing
SELECT 
    n.id,
    n.title,
    n.type,
    n.created_at,
    COUNT(nq.id) as queued_count
FROM notifications n
LEFT JOIN notification_queue nq ON n.id = nq.notification_id
WHERE n.created_at > NOW() - INTERVAL '24 hours'
GROUP BY n.id, n.title, n.type, n.created_at
ORDER BY n.created_at DESC
LIMIT 10;

-- Drop ALL existing notification triggers to clean slate
DROP TRIGGER IF EXISTS trigger_notification_push_queue ON notifications;
DROP TRIGGER IF EXISTS trigger_queue_push_notification ON notifications;  
DROP TRIGGER IF EXISTS trigger_queue_push_notifications ON notifications;

-- Drop the old trigger function with type filtering
DROP FUNCTION IF EXISTS trigger_queue_push_notification();

-- Create the corrected trigger function WITHOUT type filtering
CREATE OR REPLACE FUNCTION trigger_queue_push_notifications()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Queue for ALL new notifications (no type filtering)
    IF TG_OP = 'INSERT' THEN
        -- Log the trigger execution for debugging
        RAISE NOTICE 'Queueing push notifications for notification ID: %, type: %, title: %', 
            NEW.id, NEW.type, NEW.title;
        
        -- Call the queue function for the new notification
        PERFORM queue_push_notification(NEW.id);
        RETURN NEW;
    END IF;
    
    RETURN NULL;
END;
$$;

-- Create the ONE correct trigger
CREATE TRIGGER trigger_queue_push_notifications
    AFTER INSERT ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION trigger_queue_push_notifications();

-- Verify the setup
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'notifications'
ORDER BY trigger_name;

-- Test with a sample notification (this will create a real notification)
-- Uncomment the lines below to test immediately:
/*
INSERT INTO notifications (
    title,
    message,
    type,
    target_type,
    created_by,
    created_by_name
) VALUES (
    'Test Real Notification',
    'This is a test to verify the trigger works for all notification types',
    'info',
    'all_users', 
    'system',
    'System Test'
);
*/

-- Check that the function exists
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_name = 'queue_push_notification';