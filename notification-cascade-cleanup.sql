-- Add foreign key constraints and cascade deletion for notifications
-- This will ensure notifications are automatically cleaned up when related data is deleted

-- First, let's add a task_id column to notifications table if it doesn't exist
-- and create proper foreign key relationships

DO $$ 
BEGIN
    -- Add task_id column to notifications table if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'task_id'
    ) THEN
        ALTER TABLE notifications ADD COLUMN task_id UUID REFERENCES tasks(id) ON DELETE CASCADE;
        COMMENT ON COLUMN notifications.task_id IS 'Reference to the task this notification is about';
    END IF;

    -- Add task_assignment_id column to notifications table if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'task_assignment_id'
    ) THEN
        ALTER TABLE notifications ADD COLUMN task_assignment_id UUID REFERENCES task_assignments(id) ON DELETE CASCADE;
        COMMENT ON COLUMN notifications.task_assignment_id IS 'Reference to the task assignment this notification is about';
    END IF;
END $$;

-- Create a function to automatically clean up orphaned notifications
CREATE OR REPLACE FUNCTION cleanup_orphaned_notifications()
RETURNS void AS $$
BEGIN
    -- Delete notifications for non-existent tasks
    DELETE FROM notifications 
    WHERE type = 'task_assigned' 
    AND (
        (task_id IS NOT NULL AND task_id NOT IN (SELECT id FROM tasks))
        OR
        (task_assignment_id IS NOT NULL AND task_assignment_id NOT IN (SELECT id FROM task_assignments))
    );
    
    -- Also clean up notification read states for deleted notifications
    DELETE FROM notification_read_states 
    WHERE notification_id NOT IN (SELECT id FROM notifications);
    
    -- Clean up notification recipients for deleted notifications  
    DELETE FROM notification_recipients 
    WHERE notification_id NOT IN (SELECT id FROM notifications);
    
    -- Clean up notification attachments for deleted notifications
    DELETE FROM notification_attachments 
    WHERE notification_id NOT IN (SELECT id FROM notifications);
    
    RAISE NOTICE 'Orphaned notifications cleanup completed';
END;
$$ LANGUAGE plpgsql;

-- Create a trigger function to run cleanup when tasks are deleted
CREATE OR REPLACE FUNCTION trigger_cleanup_task_notifications()
RETURNS trigger AS $$
BEGIN
    -- Clean up notifications related to the deleted task
    DELETE FROM notifications 
    WHERE task_id = OLD.id OR (type = 'task_assigned' AND message LIKE '%' || OLD.title || '%');
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger function to run cleanup when task assignments are deleted
CREATE OR REPLACE FUNCTION trigger_cleanup_assignment_notifications()
RETURNS trigger AS $$
BEGIN
    -- Clean up notifications related to the deleted task assignment
    DELETE FROM notifications 
    WHERE task_assignment_id = OLD.id;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS cleanup_task_notifications_trigger ON tasks;
DROP TRIGGER IF EXISTS cleanup_assignment_notifications_trigger ON task_assignments;

-- Create triggers for automatic cleanup
CREATE TRIGGER cleanup_task_notifications_trigger
    AFTER DELETE ON tasks
    FOR EACH ROW
    EXECUTE FUNCTION trigger_cleanup_task_notifications();

CREATE TRIGGER cleanup_assignment_notifications_trigger
    AFTER DELETE ON task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION trigger_cleanup_assignment_notifications();

-- Run the cleanup function now to clean up any existing orphaned data
SELECT cleanup_orphaned_notifications();

COMMENT ON FUNCTION cleanup_orphaned_notifications() IS 'Manually clean up orphaned notifications and related data';
COMMENT ON FUNCTION trigger_cleanup_task_notifications() IS 'Trigger function to clean up notifications when tasks are deleted';
COMMENT ON FUNCTION trigger_cleanup_assignment_notifications() IS 'Trigger function to clean up notifications when task assignments are deleted';