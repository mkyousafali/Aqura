-- Fix notification push queue trigger
-- The automatic trigger for queuing push notifications is not working

-- First, check if the trigger exists using information_schema
SELECT 
    trigger_schema,
    trigger_name,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'notifications' 
AND trigger_name LIKE '%push%'
ORDER BY trigger_name;

-- Check if the trigger function exists
SELECT 
    routine_name,
    routine_type,
    specific_name
FROM information_schema.routines
WHERE routine_name IN ('trigger_queue_push_notification', 'queue_push_notification')
ORDER BY routine_name;

-- Now let's recreate the trigger to ensure it works
-- First drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_notification_push_queue ON notifications;

-- Recreate the trigger function
CREATE OR REPLACE FUNCTION trigger_queue_push_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Add some debugging
    RAISE NOTICE 'Push notification trigger fired for notification: %', NEW.id;
    
    -- Queue push notification for delivery
    PERFORM queue_push_notification(NEW.id);
    
    RAISE NOTICE 'Push notification queuing completed for notification: %', NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic push notification queuing
CREATE TRIGGER trigger_notification_push_queue
    AFTER INSERT ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION trigger_queue_push_notification();

-- Test the trigger by checking if it exists now
SELECT 
    trigger_schema,
    trigger_name,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'notifications' 
AND trigger_name = 'trigger_notification_push_queue';