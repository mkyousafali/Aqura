-- Notification Center Schema
-- This schema provides comprehensive notification management with role-based access control

-- Create notification types enum
CREATE TYPE public.notification_type_enum AS ENUM (
    'info',
    'success', 
    'warning',
    'error',
    'announcement'
);

-- Create notification priority enum
CREATE TYPE public.notification_priority_enum AS ENUM (
    'low',
    'medium',
    'high',
    'urgent'
);

-- Create notification status enum
CREATE TYPE public.notification_status_enum AS ENUM (
    'draft',
    'sent',
    'scheduled',
    'expired',
    'cancelled'
);

-- Create target type enum
CREATE TYPE public.notification_target_type_enum AS ENUM (
    'all_users',
    'all_admins',
    'all_employees',
    'all_managers',
    'specific_users',
    'specific_roles',
    'specific_branches',
    'specific_positions'
);

-- Main notifications table
CREATE TABLE public.notifications (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    type public.notification_type_enum NOT NULL DEFAULT 'info',
    priority public.notification_priority_enum NOT NULL DEFAULT 'medium',
    status public.notification_status_enum NOT NULL DEFAULT 'sent',
    
    -- Creator information
    created_by UUID NOT NULL,
    created_by_name VARCHAR(100) NOT NULL, -- Store creator name for display
    created_by_role VARCHAR(50) NOT NULL,  -- Store creator role for filtering
    
    -- Targeting information
    target_type public.notification_target_type_enum NOT NULL DEFAULT 'all_users',
    target_branches JSONB NULL, -- Array of branch IDs: [1, 2, 3] or "all"
    target_users JSONB NULL,    -- Array of user UUIDs for specific targeting
    target_roles JSONB NULL,    -- Array of roles: ["Admin", "Manager"]
    target_positions JSONB NULL, -- Array of position UUIDs
    
    -- Scheduling and expiry
    scheduled_at TIMESTAMP WITH TIME ZONE NULL, -- For future scheduling
    expires_at TIMESTAMP WITH TIME ZONE NULL,   -- Auto-hide after this date
    
    -- Metadata
    has_attachments BOOLEAN NOT NULL DEFAULT FALSE,
    read_count INTEGER NOT NULL DEFAULT 0,
    total_recipients INTEGER NOT NULL DEFAULT 0,
    
    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_by UUID NULL,
    
    CONSTRAINT notifications_pkey PRIMARY KEY (id),
    CONSTRAINT notifications_created_by_fkey FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT notifications_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT notifications_title_length CHECK (LENGTH(title) >= 3),
    CONSTRAINT notifications_message_length CHECK (LENGTH(message) >= 5),
    CONSTRAINT notifications_scheduled_future CHECK (scheduled_at IS NULL OR scheduled_at > created_at),
    CONSTRAINT notifications_expires_future CHECK (expires_at IS NULL OR expires_at > created_at)
) TABLESPACE pg_default;

-- Notification attachments table
CREATE TABLE public.notification_attachments (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    notification_id UUID NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_path TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    file_type VARCHAR(100) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    is_image BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Metadata
    uploaded_by UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    CONSTRAINT notification_attachments_pkey PRIMARY KEY (id),
    CONSTRAINT notification_attachments_notification_fkey FOREIGN KEY (notification_id) REFERENCES notifications (id) ON DELETE CASCADE,
    CONSTRAINT notification_attachments_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT attachment_file_size_check CHECK (file_size > 0 AND file_size <= 10485760), -- 10MB limit
    CONSTRAINT attachment_filename_length CHECK (LENGTH(file_name) >= 1 AND LENGTH(file_name) <= 255)
) TABLESPACE pg_default;

-- Notification recipients tracking table (who should receive each notification)
CREATE TABLE public.notification_recipients (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    notification_id UUID NOT NULL,
    user_id UUID NOT NULL,
    
    -- Delivery tracking
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE NULL,
    is_dismissed BOOLEAN NOT NULL DEFAULT FALSE,
    dismissed_at TIMESTAMP WITH TIME ZONE NULL,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    CONSTRAINT notification_recipients_pkey PRIMARY KEY (id),
    CONSTRAINT notification_recipients_notification_fkey FOREIGN KEY (notification_id) REFERENCES notifications (id) ON DELETE CASCADE,
    CONSTRAINT notification_recipients_user_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT notification_recipients_unique UNIQUE (notification_id, user_id),
    CONSTRAINT read_timestamp_check CHECK ((is_read = FALSE AND read_at IS NULL) OR (is_read = TRUE AND read_at IS NOT NULL)),
    CONSTRAINT dismiss_timestamp_check CHECK ((is_dismissed = FALSE AND dismissed_at IS NULL) OR (is_dismissed = TRUE AND dismissed_at IS NOT NULL))
) TABLESPACE pg_default;

-- Create indexes for performance

-- Notifications table indexes
CREATE INDEX idx_notifications_created_by ON public.notifications USING btree (created_by);
CREATE INDEX idx_notifications_type ON public.notifications USING btree (type);
CREATE INDEX idx_notifications_priority ON public.notifications USING btree (priority);
CREATE INDEX idx_notifications_status ON public.notifications USING btree (status);
CREATE INDEX idx_notifications_created_at ON public.notifications USING btree (created_at DESC);
CREATE INDEX idx_notifications_scheduled_at ON public.notifications USING btree (scheduled_at) WHERE scheduled_at IS NOT NULL;
CREATE INDEX idx_notifications_expires_at ON public.notifications USING btree (expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX idx_notifications_target_type ON public.notifications USING btree (target_type);

-- Notification attachments indexes  
CREATE INDEX idx_notification_attachments_notification_id ON public.notification_attachments USING btree (notification_id);
CREATE INDEX idx_notification_attachments_uploaded_by ON public.notification_attachments USING btree (uploaded_by);
CREATE INDEX idx_notification_attachments_created_at ON public.notification_attachments USING btree (created_at);

-- Notification recipients indexes
CREATE INDEX idx_notification_recipients_notification_id ON public.notification_recipients USING btree (notification_id);
CREATE INDEX idx_notification_recipients_user_id ON public.notification_recipients USING btree (user_id);
CREATE INDEX idx_notification_recipients_unread ON public.notification_recipients USING btree (user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notification_recipients_read_at ON public.notification_recipients USING btree (read_at DESC) WHERE read_at IS NOT NULL;
CREATE INDEX idx_notification_recipients_created_at ON public.notification_recipients USING btree (created_at DESC);

-- Composite indexes for common queries
CREATE INDEX idx_notifications_active ON public.notifications USING btree (status, created_at DESC) WHERE status IN ('sent', 'scheduled');
CREATE INDEX idx_notifications_user_targeting ON public.notifications USING btree (target_type, created_at DESC) WHERE target_type IN ('all_users', 'specific_users');
CREATE INDEX idx_recipients_user_notifications ON public.notification_recipients USING btree (user_id, created_at DESC, is_read);

-- Create triggers for updated_at columns
CREATE TRIGGER update_notifications_updated_at
    BEFORE UPDATE ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_notification_recipients_updated_at
    BEFORE UPDATE ON notification_recipients
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to automatically update notification read count
CREATE OR REPLACE FUNCTION update_notification_read_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Update read_count in notifications table when recipient read status changes
    IF TG_OP = 'UPDATE' AND OLD.is_read = FALSE AND NEW.is_read = TRUE THEN
        UPDATE notifications 
        SET read_count = read_count + 1,
            updated_at = NOW()
        WHERE id = NEW.notification_id;
    ELSIF TG_OP = 'UPDATE' AND OLD.is_read = TRUE AND NEW.is_read = FALSE THEN
        UPDATE notifications 
        SET read_count = GREATEST(read_count - 1, 0),
            updated_at = NOW()
        WHERE id = NEW.notification_id;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create trigger for read count updates
CREATE TRIGGER notification_read_count_trigger
    AFTER UPDATE ON notification_recipients
    FOR EACH ROW
    WHEN (OLD.is_read IS DISTINCT FROM NEW.is_read)
    EXECUTE FUNCTION update_notification_read_count();

-- Function to automatically update has_attachments flag
CREATE OR REPLACE FUNCTION update_notification_attachments_flag()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE notifications 
        SET has_attachments = TRUE,
            updated_at = NOW()
        WHERE id = NEW.notification_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE notifications 
        SET has_attachments = (
            SELECT COUNT(*) > 0 
            FROM notification_attachments 
            WHERE notification_id = OLD.notification_id
        ),
        updated_at = NOW()
        WHERE id = OLD.notification_id;
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for attachments flag updates
CREATE TRIGGER notification_attachments_flag_trigger
    AFTER INSERT OR DELETE ON notification_attachments
    FOR EACH ROW
    EXECUTE FUNCTION update_notification_attachments_flag();

-- Views for easier querying

-- View for notification summary with recipient statistics
CREATE VIEW notification_summary AS
SELECT 
    n.id,
    n.title,
    n.message,
    n.type,
    n.priority,
    n.status,
    n.created_by,
    n.created_by_name,
    n.created_by_role,
    n.target_type,
    n.has_attachments,
    n.read_count,
    n.total_recipients,
    n.created_at,
    n.updated_at,
    n.expires_at,
    -- Calculate read percentage
    CASE 
        WHEN n.total_recipients > 0 THEN ROUND((n.read_count::DECIMAL / n.total_recipients) * 100, 2)
        ELSE 0
    END as read_percentage,
    -- Attachment count
    COALESCE(att_count.count, 0) as attachment_count
FROM notifications n
LEFT JOIN (
    SELECT notification_id, COUNT(*) as count
    FROM notification_attachments 
    GROUP BY notification_id
) att_count ON n.id = att_count.notification_id;

-- View for user notifications (what each user can see)
CREATE VIEW user_notifications AS
SELECT 
    nr.id as recipient_id,
    nr.user_id,
    nr.is_read,
    nr.read_at,
    nr.is_dismissed,
    nr.dismissed_at,
    n.id as notification_id,
    n.title,
    n.message,
    n.type,
    n.priority,
    n.status,
    n.created_by,
    n.created_by_name,
    n.created_by_role,
    n.has_attachments,
    n.created_at,
    n.expires_at,
    -- Check if notification is still active
    CASE 
        WHEN n.expires_at IS NULL OR n.expires_at > NOW() THEN TRUE
        ELSE FALSE
    END as is_active
FROM notification_recipients nr
JOIN notifications n ON nr.notification_id = n.id
WHERE n.status = 'sent' 
AND (n.expires_at IS NULL OR n.expires_at > NOW());

-- Sample data insertion function for testing
CREATE OR REPLACE FUNCTION create_sample_notification(
    p_title TEXT,
    p_message TEXT,
    p_created_by UUID,
    p_type notification_type_enum DEFAULT 'info',
    p_priority notification_priority_enum DEFAULT 'medium',
    p_target_type notification_target_type_enum DEFAULT 'all_users'
)
RETURNS UUID AS $$
DECLARE
    notification_id UUID;
    user_record RECORD;
    recipient_count INTEGER := 0;
BEGIN
    -- Insert notification
    INSERT INTO notifications (
        title, message, type, priority, created_by, 
        created_by_name, created_by_role, target_type
    )
    SELECT 
        p_title, p_message, p_type, p_priority, p_created_by,
        u.username, COALESCE(u.role_type::TEXT, 'User'), p_target_type
    FROM users u 
    WHERE u.id = p_created_by
    RETURNING id INTO notification_id;
    
    -- Create recipients based on target type
    IF p_target_type = 'all_users' THEN
        INSERT INTO notification_recipients (notification_id, user_id)
        SELECT notification_id, u.id
        FROM users u 
        WHERE u.status = 'active';
        
        GET DIAGNOSTICS recipient_count = ROW_COUNT;
    END IF;
    
    -- Update total recipients count
    UPDATE notifications 
    SET total_recipients = recipient_count
    WHERE id = notification_id;
    
    RETURN notification_id;
END;
$$ LANGUAGE plpgsql;

-- Comments for documentation
COMMENT ON TABLE notifications IS 'Main notifications table storing notification content and metadata';
COMMENT ON TABLE notification_attachments IS 'File attachments associated with notifications';
COMMENT ON TABLE notification_recipients IS 'Tracks which users should receive each notification and their read status';
COMMENT ON VIEW notification_summary IS 'Summary view of notifications with recipient statistics';
COMMENT ON VIEW user_notifications IS 'User-specific view showing notifications each user can see';

-- Grant appropriate permissions (adjust as needed for your security model)
-- These are examples - adjust based on your actual role structure

-- Example: Grant permissions to notification_admin role
-- GRANT ALL PRIVILEGES ON notifications TO notification_admin;
-- GRANT ALL PRIVILEGES ON notification_attachments TO notification_admin;
-- GRANT ALL PRIVILEGES ON notification_recipients TO notification_admin;

-- Example: Grant read permissions to regular users
-- GRANT SELECT ON user_notifications TO authenticated_users;
-- GRANT UPDATE (is_read, read_at, is_dismissed, dismissed_at) ON notification_recipients TO authenticated_users;