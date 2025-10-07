-- Enhanced Quick Task Notifications with Assignment Details
-- This script updates the notification function to show who assigned the task and to whom

-- First, let's update the create_quick_task_notification function to include user names
CREATE OR REPLACE FUNCTION create_quick_task_notification()
RETURNS TRIGGER AS $$
DECLARE
    assigned_by_name TEXT;
    assigned_to_name TEXT;
BEGIN
    -- Get the name of who assigned the task (from hr_employees if available, otherwise username)
    SELECT COALESCE(he.name, u.username, 'Admin') INTO assigned_by_name
    FROM users u
    LEFT JOIN hr_employees he ON u.employee_id = he.id
    WHERE u.id = (SELECT assigned_by FROM quick_tasks WHERE id = NEW.quick_task_id);
    
    -- Get the name of who the task is assigned to (from hr_employees if available, otherwise username)
    SELECT COALESCE(he.name, u.username, 'User') INTO assigned_to_name
    FROM users u
    LEFT JOIN hr_employees he ON u.employee_id = he.id
    WHERE u.id = NEW.assigned_to_user_id;
    
    -- Insert notification for each assigned user
    INSERT INTO notifications (
        title,
        message,
        type,
        priority,
        target_type,
        target_users,
        created_by,
        created_by_name,
        metadata,
        created_at
    )
    SELECT 
        'New Quick Task: ' || qt.title,
        'You have been assigned a new quick task: "' || qt.title || 
        '" by ' || COALESCE(assigned_by_name, 'Admin') || 
        '. Priority: ' || qt.priority || 
        '. Deadline: ' || to_char(qt.deadline_datetime, 'YYYY-MM-DD HH24:MI') ||
        CASE 
            WHEN qt.description IS NOT NULL AND qt.description != '' 
            THEN E'\n\nDescription: ' || qt.description
            ELSE ''
        END,
        'task_assignment',
        qt.priority,
        'specific_users',
        jsonb_build_array(NEW.assigned_to_user_id),
        qt.assigned_by::text,
        COALESCE(assigned_by_name, 'Admin'),
        jsonb_build_object(
            'quick_task_id', qt.id,
            'task_title', qt.title,
            'deadline', qt.deadline_datetime,
            'priority', qt.priority,
            'issue_type', qt.issue_type,
            'assigned_by', qt.assigned_by,
            'assigned_by_name', assigned_by_name,
            'assigned_to_user_id', NEW.assigned_to_user_id,
            'assigned_to_name', assigned_to_name,
            'quick_task_assignment_id', NEW.id,
            'assignment_details', 'Assigned by ' || COALESCE(assigned_by_name, 'Admin') || ' to ' || COALESCE(assigned_to_name, 'User')
        ),
        NOW()
    FROM quick_tasks qt
    WHERE qt.id = NEW.quick_task_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update the existing trigger (it should already exist, but this ensures it's using the new function)
DROP TRIGGER IF EXISTS trigger_create_quick_task_notification ON quick_task_assignments;
CREATE TRIGGER trigger_create_quick_task_notification
    AFTER INSERT ON quick_task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION create_quick_task_notification();

-- Also update the queue function to include better payload information
CREATE OR REPLACE FUNCTION queue_quick_task_push_notifications()
RETURNS TRIGGER AS $$
DECLARE
    user_record RECORD;
    notification_payload jsonb;
BEGIN
    -- Only process if this is a task assignment notification
    IF NEW.type = 'task_assignment' AND NEW.target_users IS NOT NULL THEN
        -- Extract assignment details from metadata
        notification_payload := jsonb_build_object(
            'title', NEW.title,
            'body', NEW.message,
            'icon', '/favicon.ico',
            'badge', '/favicon.ico',
            'data', jsonb_build_object(
                'notificationId', NEW.id,
                'type', NEW.type,
                'quick_task_id', (NEW.metadata->>'quick_task_id'),
                'assignment_details', (NEW.metadata->>'assignment_details'),
                'url', '/mobile/quick-task'
            )
        );

        -- Queue push notifications for each target user
        FOR user_record IN 
            SELECT DISTINCT jsonb_array_elements_text(NEW.target_users) as user_id
        LOOP
            INSERT INTO notification_queue (
                notification_id,
                user_id,
                status,
                payload,
                created_at
            ) VALUES (
                NEW.id,
                user_record.user_id::uuid,
                'pending',
                notification_payload,
                NOW()
            );
        END LOOP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update the existing trigger for the queue function
DROP TRIGGER IF EXISTS trigger_queue_quick_task_push_notifications ON notifications;
CREATE TRIGGER trigger_queue_quick_task_push_notifications
    AFTER INSERT ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION queue_quick_task_push_notifications();

-- Test the updated function with a comment explaining the enhancement
COMMENT ON FUNCTION create_quick_task_notification() IS 'Enhanced notification function that includes assignment details showing who assigned the task to whom';
COMMENT ON FUNCTION queue_quick_task_push_notifications() IS 'Enhanced queue function with better payload information for Quick Task notifications';