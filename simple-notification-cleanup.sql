-- Simple and effective cleanup of orphaned notifications
-- This approach is more straightforward and should handle your specific case

-- Step 1: Show current state
SELECT 
    COUNT(*) as total_notifications,
    COUNT(CASE WHEN type = 'task_assigned' THEN 1 END) as task_assigned_notifications
FROM notifications;

-- Step 2: Show some examples of what we're cleaning
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
LIMIT 3;

-- Step 3: Simple cleanup - Remove all task_assigned notifications that don't have valid references
-- This will remove notifications for deleted tasks regardless of how they're structured

-- First: Clean notifications with explicit task_id references to non-existent tasks
DELETE FROM notifications 
WHERE type = 'task_assigned' 
AND task_id IS NOT NULL 
AND task_id NOT IN (SELECT id FROM tasks);

-- Second: Clean notifications with explicit task_assignment_id references to non-existent assignments
DELETE FROM notifications 
WHERE type = 'task_assigned' 
AND task_assignment_id IS NOT NULL 
AND task_assignment_id NOT IN (SELECT id FROM task_assignments);

-- Third: Clean notifications that reference assignments for deleted tasks
DELETE FROM notifications 
WHERE type = 'task_assigned' 
AND task_assignment_id IS NOT NULL
AND task_assignment_id IN (
    SELECT ta.id 
    FROM task_assignments ta 
    LEFT JOIN tasks t ON ta.task_id = t.id 
    WHERE t.id IS NULL
);

-- Fourth: The nuclear option - remove ALL task_assigned notifications that can't be linked to existing tasks
-- This checks if any existing task matches any part of the notification message
DELETE FROM notifications 
WHERE type = 'task_assigned' 
AND id NOT IN (
    SELECT DISTINCT n.id
    FROM notifications n
    CROSS JOIN tasks t
    WHERE n.type = 'task_assigned'
    AND (
        n.message ILIKE '%' || t.title || '%'
        OR (n.metadata->>'task_title') = t.title
        OR (n.metadata->>'task_id')::text = t.id::text
        OR n.task_id = t.id
        OR n.task_assignment_id IN (
            SELECT ta.id FROM task_assignments ta WHERE ta.task_id = t.id
        )
    )
);

-- Step 4: Clean up orphaned related data
DELETE FROM notification_read_states 
WHERE notification_id NOT IN (SELECT id FROM notifications);

DELETE FROM notification_recipients 
WHERE notification_id NOT IN (SELECT id FROM notifications);

DELETE FROM notification_attachments 
WHERE notification_id NOT IN (SELECT id FROM notifications);

-- Step 5: Show final results
SELECT 
    COUNT(*) as total_notifications_after,
    COUNT(CASE WHEN type = 'task_assigned' THEN 1 END) as task_assigned_after
FROM notifications;

-- Step 6: Show any remaining task_assigned notifications
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
LIMIT 5;