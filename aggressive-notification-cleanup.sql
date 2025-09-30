-- Aggressive cleanup of orphaned notifications
-- This will clean up ALL task_assigned notifications that don't have valid task references

-- Step 1: First, let's see what we're dealing with
SELECT 
    COUNT(*) as total_notifications,
    COUNT(CASE WHEN type = 'task_assigned' THEN 1 END) as task_assigned_notifications,
    COUNT(CASE WHEN type = 'task_assigned' AND task_id IS NOT NULL THEN 1 END) as with_task_id,
    COUNT(CASE WHEN type = 'task_assigned' AND task_assignment_id IS NOT NULL THEN 1 END) as with_assignment_id
FROM notifications;

-- Step 2: Show sample of problematic notifications
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
LIMIT 5;

-- Step 3: More aggressive cleanup - Delete task_assigned notifications where we can't find the referenced task
-- Method 1: Clean up notifications with task_id that don't exist
DELETE FROM notifications 
WHERE type = 'task_assigned' 
AND task_id IS NOT NULL 
AND task_id NOT IN (SELECT id FROM tasks);

-- Method 2: Clean up notifications with task_assignment_id that don't exist
DELETE FROM notifications 
WHERE type = 'task_assigned' 
AND task_assignment_id IS NOT NULL 
AND task_assignment_id NOT IN (SELECT id FROM task_assignments);

-- Method 3: Clean up notifications where we can extract task names that don't exist
-- This targets notifications like "You have been assigned a new task: 'test'" where 'test' task doesn't exist
DELETE FROM notifications 
WHERE type = 'task_assigned' 
AND id IN (
    SELECT n.id 
    FROM notifications n
    WHERE n.type = 'task_assigned'
    AND NOT EXISTS (
        SELECT 1 FROM tasks t 
        WHERE (
            -- Check if task title appears in message
            n.message ILIKE '%task: "' || t.title || '"%' 
            OR n.message ILIKE '%task "' || t.title || '"%'
            OR n.message ILIKE '%task: ''' || t.title || '''%'
            OR n.message ILIKE '%task ''' || t.title || '''%'
            -- Check metadata
            OR (n.metadata->>'task_title')::text = t.title
            OR (n.metadata->>'task_id')::text = t.id::text
        )
    )
    -- Only delete if we can extract a task name from the message
    AND (
        n.message ~* 'task: "[^"]+"|task: ''[^'']+'''
        OR n.message ~* 'task "[^"]+"|task ''[^'']+'
        OR n.metadata ? 'task_title'
        OR n.metadata ? 'task_id'
    )
);

-- Method 4: Clean up any remaining task_assigned notifications that have no valid references
-- This is the nuclear option - clean up all task_assigned notifications that can't be linked to existing tasks
DELETE FROM notifications 
WHERE type = 'task_assigned' 
AND (
    -- No foreign key references at all
    (task_id IS NULL AND task_assignment_id IS NULL)
    OR 
    -- Has task_id but task doesn't exist
    (task_id IS NOT NULL AND task_id NOT IN (SELECT id FROM tasks))
    OR
    -- Has task_assignment_id but assignment doesn't exist
    (task_assignment_id IS NOT NULL AND task_assignment_id NOT IN (SELECT id FROM task_assignments))
    OR
    -- Has task_assignment_id but the task for that assignment doesn't exist
    (task_assignment_id IS NOT NULL AND task_assignment_id IN (
        SELECT ta.id FROM task_assignments ta 
        LEFT JOIN tasks t ON ta.task_id = t.id 
        WHERE t.id IS NULL
    ))
);

-- Step 5: Clean up orphaned related records
DELETE FROM notification_read_states 
WHERE notification_id NOT IN (SELECT id FROM notifications);

DELETE FROM notification_recipients 
WHERE notification_id NOT IN (SELECT id FROM notifications);

DELETE FROM notification_attachments 
WHERE notification_id NOT IN (SELECT id FROM notifications);

-- Step 6: Final verification - show what's left
SELECT 
    COUNT(*) as total_notifications_after,
    COUNT(CASE WHEN type = 'task_assigned' THEN 1 END) as task_assigned_after_cleanup
FROM notifications;

-- Step 7: Show any remaining task_assigned notifications
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