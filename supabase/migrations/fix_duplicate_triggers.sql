-- ============================================================
-- FIX DUPLICATE PUSH NOTIFICATION TRIGGERS
-- ============================================================
-- Problem: Multiple triggers firing on notification insert
-- causing 3 queue entries instead of 1
-- ============================================================

-- Step 1: Check current triggers (for reference)
SELECT 
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    tgenabled as enabled,
    proname as function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'notifications'::regclass
ORDER BY tgname;

-- Step 2: Drop ALL push notification triggers
DROP TRIGGER IF EXISTS trigger_queue_push_notification ON notifications;
DROP TRIGGER IF EXISTS trigger_queue_push_notifications ON notifications;
DROP TRIGGER IF EXISTS trigger_queue_quick_task_push_notifications ON notifications;

-- Step 3: Keep only ONE trigger - the main one
-- This trigger will handle ALL notification types
CREATE TRIGGER trigger_queue_push_notification
    AFTER INSERT ON notifications
    FOR EACH ROW
    WHEN (NEW.status = 'published')
    EXECUTE FUNCTION queue_push_notification_trigger();

-- Step 4: Verify only one trigger exists now
SELECT 
    'Trigger cleanup complete!' as message,
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    tgenabled as enabled,
    proname as function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'notifications'::regclass
AND tgname LIKE '%push%'
ORDER BY tgname;

-- ============================================================
-- EXPLANATION:
-- ============================================================
-- Previously had 3 triggers:
-- 1. trigger_queue_push_notification (main)
-- 2. trigger_queue_push_notifications (duplicate with 's')
-- 3. trigger_queue_quick_task_push_notifications (task-specific)
--
-- Now keeping only ONE that handles all cases
-- The queue_push_notification function already handles all logic
-- ============================================================

-- Step 5: Test with a notification
-- Uncomment below to test (should create only 1 queue entry per device)
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
    'Test Single Trigger',
    'This should create only 1 queue entry per device',
    ARRAY['b658eca1-3cc1-48b2-bd3c-33b81fab5a0f']::uuid[],
    'specific_users',
    'info',
    'medium',
    'published',
    'system',
    'System Test',
    'Admin'
) RETURNING id;

-- Then check queue count:
-- SELECT COUNT(*) as queue_entries 
-- FROM notification_queue 
-- WHERE notification_id = '<id from above>';
-- Should show 1 entry (or number of devices user has)
*/
