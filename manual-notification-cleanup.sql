-- Manual cleanup of orphaned notifications
-- This script will clean up notifications for deleted tasks even if they don't have proper foreign key references

-- Step 1: Clean up notifications that reference non-existent tasks by parsing the message content
DELETE FROM notifications 
WHERE type = 'task_assigned' 
AND id IN (
    SELECT n.id 
    FROM notifications n
    LEFT JOIN tasks t ON (
        -- Try to match by task title in the message
        n.message LIKE '%task: "' || t.title || '"%' 
        OR n.message LIKE '%task "' || t.title || '"%'
        OR (n.metadata->>'task_title')::text = t.title
        OR (n.metadata->>'task_id')::uuid = t.id
    )
    WHERE n.type = 'task_assigned' 
    AND t.id IS NULL
);

-- Step 2: Clean up notifications that have task_id but the task doesn't exist
DELETE FROM notifications 
WHERE task_id IS NOT NULL 
AND task_id NOT IN (SELECT id FROM tasks);

-- Step 3: Clean up notifications that have task_assignment_id but the assignment doesn't exist  
DELETE FROM notifications 
WHERE task_assignment_id IS NOT NULL 
AND task_assignment_id NOT IN (SELECT id FROM task_assignments);

-- Step 4: Clean up notifications for task assignments where the task no longer exists
DELETE FROM notifications 
WHERE type = 'task_assigned'
AND task_assignment_id IN (
    SELECT ta.id 
    FROM task_assignments ta
    LEFT JOIN tasks t ON ta.task_id = t.id
    WHERE t.id IS NULL
);

-- Step 5: Clean up orphaned notification read states
DELETE FROM notification_read_states 
WHERE notification_id NOT IN (SELECT id FROM notifications);

-- Step 6: Clean up orphaned notification recipients
DELETE FROM notification_recipients 
WHERE notification_id NOT IN (SELECT id FROM notifications);

-- Step 7: Clean up orphaned notification attachments
DELETE FROM notification_attachments 
WHERE notification_id NOT IN (SELECT id FROM notifications);

-- Step 8: Show remaining notifications count
SELECT 
    COUNT(*) as total_notifications,
    COUNT(CASE WHEN type = 'task_assigned' THEN 1 END) as task_assigned_notifications
FROM notifications;

-- Step 9: Show any remaining task_assigned notifications for verification
SELECT 
    id,
    type,
    message,
    metadata,
    task_id,
    task_assignment_id,
    created_at
FROM notifications 
WHERE type = 'task_assigned'
ORDER BY created_at DESC
LIMIT 10;