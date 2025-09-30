-- DEFINITIVE CLEANUP: Remove ALL task_assigned notifications
-- Since you confirmed there are no tasks assigned at all, we can safely remove all task_assigned notifications

-- Step 1: Show current state before cleanup
SELECT 
    COUNT(*) as total_notifications_before,
    COUNT(CASE WHEN type = 'task_assigned' THEN 1 END) as task_assigned_notifications_before,
    COUNT(CASE WHEN type != 'task_assigned' THEN 1 END) as other_notifications_before
FROM notifications;

-- Step 2: Show what task_assigned notifications we're about to delete
SELECT 
    id,
    type,
    message,
    task_id,
    task_assignment_id,
    created_at
FROM notifications 
WHERE type = 'task_assigned'
ORDER BY created_at DESC
LIMIT 10;

-- Step 3: NUCLEAR OPTION - Delete ALL task_assigned notifications
-- Since there are no valid task assignments, we can safely remove all of them
DELETE FROM notifications 
WHERE type = 'task_assigned';

-- Step 4: Clean up all orphaned related data
DELETE FROM notification_read_states 
WHERE notification_id NOT IN (SELECT id FROM notifications);

DELETE FROM notification_recipients 
WHERE notification_id NOT IN (SELECT id FROM notifications);

DELETE FROM notification_attachments 
WHERE notification_id NOT IN (SELECT id FROM notifications);

-- Step 5: Verify cleanup - show final state
SELECT 
    COUNT(*) as total_notifications_after,
    COUNT(CASE WHEN type = 'task_assigned' THEN 1 END) as task_assigned_notifications_after,
    COUNT(CASE WHEN type != 'task_assigned' THEN 1 END) as other_notifications_after
FROM notifications;

-- Step 6: Show remaining notifications by type
SELECT 
    type,
    COUNT(*) as count
FROM notifications 
GROUP BY type
ORDER BY count DESC;

-- Step 7: Show any remaining notifications
SELECT 
    id,
    type,
    message,
    created_at
FROM notifications 
ORDER BY created_at DESC
LIMIT 5;