-- Create notifications table for managing system notifications
-- This table stores all notifications with targeting and scheduling capabilities

-- Create the notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    title CHARACTER VARYING(255) NOT NULL,
    message TEXT NOT NULL,
    created_by CHARACTER VARYING(255) NOT NULL DEFAULT 'system'::character varying,
    created_by_name CHARACTER VARYING(100) NOT NULL DEFAULT 'System'::character varying,
    created_by_role CHARACTER VARYING(50) NOT NULL DEFAULT 'Admin'::character varying,
    target_users JSONB NULL,
    target_roles JSONB NULL,
    target_branches JSONB NULL,
    scheduled_for TIMESTAMP WITH TIME ZONE NULL,
    sent_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    expires_at TIMESTAMP WITH TIME ZONE NULL,
    has_attachments BOOLEAN NOT NULL DEFAULT false,
    read_count INTEGER NOT NULL DEFAULT 0,
    total_recipients INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    deleted_at TIMESTAMP WITH TIME ZONE NULL,
    metadata JSONB NULL,
    task_id UUID NULL,
    task_assignment_id UUID NULL,
    priority CHARACTER VARYING(20) NOT NULL DEFAULT 'medium'::character varying,
    status CHARACTER VARYING(20) NOT NULL DEFAULT 'published'::character varying,
    target_type CHARACTER VARYING(50) NOT NULL DEFAULT 'all_users'::character varying,
    type CHARACTER VARYING(50) NOT NULL DEFAULT 'info'::character varying,
    
    CONSTRAINT notifications_pkey PRIMARY KEY (id),
    CONSTRAINT notifications_task_assignment_id_fkey 
        FOREIGN KEY (task_assignment_id) REFERENCES task_assignments (id) ON DELETE CASCADE,
    CONSTRAINT notifications_task_id_fkey 
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_notifications_created_at 
ON public.notifications USING btree (created_at DESC) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_notifications_status 
ON public.notifications (status);

CREATE INDEX IF NOT EXISTS idx_notifications_type 
ON public.notifications (type);

CREATE INDEX IF NOT EXISTS idx_notifications_priority 
ON public.notifications (priority);

CREATE INDEX IF NOT EXISTS idx_notifications_target_type 
ON public.notifications (target_type);

CREATE INDEX IF NOT EXISTS idx_notifications_scheduled_for 
ON public.notifications (scheduled_for) 
WHERE scheduled_for IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_expires_at 
ON public.notifications (expires_at) 
WHERE expires_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_task_id 
ON public.notifications (task_id) 
WHERE task_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_task_assignment_id 
ON public.notifications (task_assignment_id) 
WHERE task_assignment_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_created_by 
ON public.notifications (created_by);

CREATE INDEX IF NOT EXISTS idx_notifications_sent_at 
ON public.notifications (sent_at) 
WHERE sent_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_deleted_at 
ON public.notifications (deleted_at) 
WHERE deleted_at IS NOT NULL;

-- Create GIN indexes for JSONB columns
CREATE INDEX IF NOT EXISTS idx_notifications_target_users_gin 
ON public.notifications USING gin (target_users) 
WHERE target_users IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_target_roles_gin 
ON public.notifications USING gin (target_roles) 
WHERE target_roles IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_target_branches_gin 
ON public.notifications USING gin (target_branches) 
WHERE target_branches IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_metadata_gin 
ON public.notifications USING gin (metadata) 
WHERE metadata IS NOT NULL;

-- Create text search index for title and message
CREATE INDEX IF NOT EXISTS idx_notifications_text_search 
ON public.notifications USING gin (to_tsvector('english', title || ' ' || message));

-- Create composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_notifications_status_created 
ON public.notifications (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_type_priority 
ON public.notifications (type, priority, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_active 
ON public.notifications (status, expires_at, created_at DESC) 
WHERE deleted_at IS NULL;

-- Add trigger for updated_at
CREATE OR REPLACE FUNCTION update_notifications_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_notifications_updated_at 
BEFORE UPDATE ON notifications 
FOR EACH ROW 
EXECUTE FUNCTION update_notifications_updated_at();

-- Add data validation constraints
ALTER TABLE public.notifications 
ADD CONSTRAINT chk_title_not_empty 
CHECK (TRIM(title) != '');

ALTER TABLE public.notifications 
ADD CONSTRAINT chk_message_not_empty 
CHECK (TRIM(message) != '');

ALTER TABLE public.notifications 
ADD CONSTRAINT chk_priority_valid 
CHECK (priority IN ('low', 'medium', 'high', 'urgent'));

ALTER TABLE public.notifications 
ADD CONSTRAINT chk_status_valid 
CHECK (status IN ('draft', 'scheduled', 'published', 'sent', 'expired', 'cancelled'));

ALTER TABLE public.notifications 
ADD CONSTRAINT chk_type_valid 
CHECK (type IN ('info', 'warning', 'error', 'success', 'task', 'reminder', 'announcement', 'alert'));

ALTER TABLE public.notifications 
ADD CONSTRAINT chk_target_type_valid 
CHECK (target_type IN ('all_users', 'specific_users', 'roles', 'branches', 'custom'));

ALTER TABLE public.notifications 
ADD CONSTRAINT chk_read_count_non_negative 
CHECK (read_count >= 0);

ALTER TABLE public.notifications 
ADD CONSTRAINT chk_total_recipients_non_negative 
CHECK (total_recipients >= 0);

ALTER TABLE public.notifications 
ADD CONSTRAINT chk_read_count_within_total 
CHECK (read_count <= total_recipients);

ALTER TABLE public.notifications 
ADD CONSTRAINT chk_expires_after_created 
CHECK (expires_at IS NULL OR expires_at > created_at);

-- Add table and column comments
COMMENT ON TABLE public.notifications IS 'System notifications with targeting and scheduling capabilities';
COMMENT ON COLUMN public.notifications.id IS 'Unique identifier for the notification';
COMMENT ON COLUMN public.notifications.title IS 'Notification title/subject';
COMMENT ON COLUMN public.notifications.message IS 'Notification content/body';
COMMENT ON COLUMN public.notifications.created_by IS 'User ID or system identifier who created the notification';
COMMENT ON COLUMN public.notifications.created_by_name IS 'Display name of notification creator';
COMMENT ON COLUMN public.notifications.created_by_role IS 'Role of notification creator';
COMMENT ON COLUMN public.notifications.target_users IS 'JSON array of specific user IDs to target';
COMMENT ON COLUMN public.notifications.target_roles IS 'JSON array of roles to target';
COMMENT ON COLUMN public.notifications.target_branches IS 'JSON array of branches to target';
COMMENT ON COLUMN public.notifications.scheduled_for IS 'When the notification should be sent (NULL for immediate)';
COMMENT ON COLUMN public.notifications.sent_at IS 'When the notification was actually sent';
COMMENT ON COLUMN public.notifications.expires_at IS 'When the notification expires and should be hidden';
COMMENT ON COLUMN public.notifications.has_attachments IS 'Whether this notification has file attachments';
COMMENT ON COLUMN public.notifications.read_count IS 'Number of recipients who have read this notification';
COMMENT ON COLUMN public.notifications.total_recipients IS 'Total number of intended recipients';
COMMENT ON COLUMN public.notifications.task_id IS 'Associated task if this is a task-related notification';
COMMENT ON COLUMN public.notifications.task_assignment_id IS 'Associated task assignment if applicable';
COMMENT ON COLUMN public.notifications.priority IS 'Notification priority level';
COMMENT ON COLUMN public.notifications.status IS 'Current status of the notification';
COMMENT ON COLUMN public.notifications.target_type IS 'Type of targeting used';
COMMENT ON COLUMN public.notifications.type IS 'Category/type of notification';
COMMENT ON COLUMN public.notifications.metadata IS 'Additional metadata in JSON format';

-- Create trigger functions for push notifications
CREATE OR REPLACE FUNCTION trigger_queue_push_notifications()
RETURNS TRIGGER AS $$
BEGIN
    -- Queue push notifications for the new notification
    -- This function will be called after a notification is inserted
    
    -- Log the notification creation
    RAISE NOTICE 'Notification created: % (ID: %)', NEW.title, NEW.id;
    
    -- Add logic here to queue push notifications based on targeting
    -- This is a placeholder - actual implementation depends on your push notification system
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION queue_quick_task_push_notifications()
RETURNS TRIGGER AS $$
BEGIN
    -- Queue push notifications specifically for quick task notifications
    -- This function handles task-related notification push logic
    
    IF NEW.task_id IS NOT NULL OR NEW.task_assignment_id IS NOT NULL THEN
        RAISE NOTICE 'Task notification created: % (Task ID: %, Assignment ID: %)', 
                     NEW.title, NEW.task_id, NEW.task_assignment_id;
        
        -- Add specific task notification push logic here
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the triggers
CREATE TRIGGER trigger_queue_push_notifications
AFTER INSERT ON notifications 
FOR EACH ROW 
EXECUTE FUNCTION trigger_queue_push_notifications();

CREATE TRIGGER trigger_queue_quick_task_push_notifications
AFTER INSERT ON notifications 
FOR EACH ROW 
EXECUTE FUNCTION queue_quick_task_push_notifications();

-- Create view for active notifications
CREATE OR REPLACE VIEW active_notifications AS
SELECT 
    n.id,
    n.title,
    n.message,
    n.type,
    n.priority,
    n.status,
    n.target_type,
    n.created_by_name,
    n.created_by_role,
    n.has_attachments,
    n.read_count,
    n.total_recipients,
    n.task_id,
    n.task_assignment_id,
    n.scheduled_for,
    n.sent_at,
    n.expires_at,
    n.created_at,
    CASE 
        WHEN n.read_count > 0 AND n.total_recipients > 0 
        THEN ROUND((n.read_count * 100.0) / n.total_recipients, 2)
        ELSE 0
    END as read_percentage
FROM notifications n
WHERE n.deleted_at IS NULL
  AND n.status != 'cancelled'
  AND (n.expires_at IS NULL OR n.expires_at > now())
ORDER BY n.created_at DESC;

-- Create function to get notifications by target criteria
CREATE OR REPLACE FUNCTION get_notifications_for_user(
    user_id_param UUID,
    user_role_param VARCHAR DEFAULT NULL,
    user_branch_param VARCHAR DEFAULT NULL,
    limit_count INTEGER DEFAULT 50
)
RETURNS TABLE(
    notification_id UUID,
    title VARCHAR,
    message TEXT,
    type VARCHAR,
    priority VARCHAR,
    has_attachments BOOLEAN,
    task_id UUID,
    task_assignment_id UUID,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.id,
        n.title,
        n.message,
        n.type,
        n.priority,
        n.has_attachments,
        n.task_id,
        n.task_assignment_id,
        n.sent_at,
        n.created_at
    FROM notifications n
    WHERE n.deleted_at IS NULL
      AND n.status = 'published'
      AND (n.expires_at IS NULL OR n.expires_at > now())
      AND (
          n.target_type = 'all_users' OR
          (n.target_type = 'specific_users' AND n.target_users @> to_jsonb(user_id_param::text)) OR
          (n.target_type = 'roles' AND user_role_param IS NOT NULL AND n.target_roles @> to_jsonb(user_role_param)) OR
          (n.target_type = 'branches' AND user_branch_param IS NOT NULL AND n.target_branches @> to_jsonb(user_branch_param))
      )
    ORDER BY n.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to update read count
CREATE OR REPLACE FUNCTION increment_notification_read_count(notif_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE notifications 
    SET read_count = read_count + 1,
        updated_at = now()
    WHERE id = notif_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to get notification statistics
CREATE OR REPLACE FUNCTION get_notification_statistics()
RETURNS TABLE(
    total_notifications BIGINT,
    published_count BIGINT,
    draft_count BIGINT,
    scheduled_count BIGINT,
    expired_count BIGINT,
    avg_read_rate NUMERIC,
    notifications_with_attachments BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_notifications,
        COUNT(*) FILTER (WHERE status = 'published') as published_count,
        COUNT(*) FILTER (WHERE status = 'draft') as draft_count,
        COUNT(*) FILTER (WHERE status = 'scheduled') as scheduled_count,
        COUNT(*) FILTER (WHERE expires_at IS NOT NULL AND expires_at <= now()) as expired_count,
        CASE 
            WHEN SUM(total_recipients) > 0 
            THEN ROUND((SUM(read_count) * 100.0) / SUM(total_recipients), 2)
            ELSE 0
        END as avg_read_rate,
        COUNT(*) FILTER (WHERE has_attachments = true) as notifications_with_attachments
    FROM notifications
    WHERE deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'notifications table created with comprehensive notification management features';