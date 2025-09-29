-- =====================================================
-- Table: notification_recipients
-- Description: Manages notification recipients and their read/dismissed status
-- This table tracks which users receive notifications and their interaction status
-- =====================================================

-- Create notification_recipients table
CREATE TABLE public.notification_recipients (
    -- Primary key with UUID generation
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    
    -- Foreign key to notifications table
    notification_id UUID NOT NULL,
    
    -- User identification (string-based user ID)
    user_id CHARACTER VARYING(255) NOT NULL,
    
    -- Optional role-based targeting
    role CHARACTER VARYING(100) NULL,
    
    -- Optional branch-based targeting
    branch_id CHARACTER VARYING(255) NULL,
    
    -- Read status tracking
    is_read BOOLEAN NOT NULL DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE NULL,
    
    -- Dismissed status tracking
    is_dismissed BOOLEAN NOT NULL DEFAULT false,
    dismissed_at TIMESTAMP WITH TIME ZONE NULL,
    
    -- Audit timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    
    -- Primary key constraint
    CONSTRAINT notification_recipients_pkey PRIMARY KEY (id),
    
    -- Unique constraint to prevent duplicate recipients per notification
    CONSTRAINT notification_recipients_unique UNIQUE (notification_id, user_id),
    
    -- Foreign key to notifications table with CASCADE delete
    CONSTRAINT notification_recipients_notification_fkey 
        FOREIGN KEY (notification_id) 
        REFERENCES notifications (id) 
        ON DELETE CASCADE
) TABLESPACE pg_default;

-- =====================================================
-- Indexes for Performance Optimization
-- =====================================================

-- Index for user-based queries
CREATE INDEX IF NOT EXISTS idx_notification_recipients_user_id 
    ON public.notification_recipients 
    USING btree (user_id) 
    TABLESPACE pg_default;

-- Partial index for unread notifications per user (performance optimization)
CREATE INDEX IF NOT EXISTS idx_notification_recipients_unread 
    ON public.notification_recipients 
    USING btree (user_id, is_read) 
    TABLESPACE pg_default
    WHERE (is_read = false);

-- Additional performance indexes
CREATE INDEX IF NOT EXISTS idx_notification_recipients_notification_id 
    ON public.notification_recipients 
    USING btree (notification_id) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_recipients_role 
    ON public.notification_recipients 
    USING btree (role) 
    TABLESPACE pg_default
    WHERE role IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notification_recipients_branch 
    ON public.notification_recipients 
    USING btree (branch_id) 
    TABLESPACE pg_default
    WHERE branch_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notification_recipients_created_at 
    ON public.notification_recipients 
    USING btree (created_at DESC) 
    TABLESPACE pg_default;

-- Composite index for efficient dashboard queries
CREATE INDEX IF NOT EXISTS idx_notification_recipients_user_status 
    ON public.notification_recipients 
    USING btree (user_id, is_read, is_dismissed, created_at DESC) 
    TABLESPACE pg_default;

-- =====================================================
-- Triggers for Automatic Updates
-- =====================================================

-- Create trigger function for updating updated_at timestamp
CREATE OR REPLACE FUNCTION update_notification_recipients_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic timestamp updates
CREATE TRIGGER trigger_update_notification_recipients_updated_at
    BEFORE UPDATE ON public.notification_recipients
    FOR EACH ROW
    EXECUTE FUNCTION update_notification_recipients_updated_at();

-- Trigger to automatically set read_at timestamp when is_read changes to true
CREATE OR REPLACE FUNCTION set_notification_read_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    -- Set read_at when marking as read
    IF NEW.is_read = true AND OLD.is_read = false THEN
        NEW.read_at = now();
    END IF;
    
    -- Clear read_at when marking as unread
    IF NEW.is_read = false AND OLD.is_read = true THEN
        NEW.read_at = NULL;
    END IF;
    
    -- Set dismissed_at when marking as dismissed
    IF NEW.is_dismissed = true AND OLD.is_dismissed = false THEN
        NEW.dismissed_at = now();
    END IF;
    
    -- Clear dismissed_at when un-dismissing
    IF NEW.is_dismissed = false AND OLD.is_dismissed = true THEN
        NEW.dismissed_at = NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic status timestamp management
CREATE TRIGGER trigger_notification_recipients_status_timestamps
    BEFORE UPDATE ON public.notification_recipients
    FOR EACH ROW
    EXECUTE FUNCTION set_notification_read_timestamp();

-- =====================================================
-- Table Comments for Documentation
-- =====================================================

COMMENT ON TABLE public.notification_recipients IS 'Tracks notification recipients and their read/dismissed status for personalized notification management';

COMMENT ON COLUMN public.notification_recipients.id IS 'Primary key - unique identifier for each recipient record';
COMMENT ON COLUMN public.notification_recipients.notification_id IS 'Foreign key to notifications table - which notification this recipient entry is for';
COMMENT ON COLUMN public.notification_recipients.user_id IS 'String-based user identifier - recipient of the notification';
COMMENT ON COLUMN public.notification_recipients.role IS 'Optional role-based targeting - notifications can be sent to specific roles';
COMMENT ON COLUMN public.notification_recipients.branch_id IS 'Optional branch-based targeting - notifications can be sent to specific branches';
COMMENT ON COLUMN public.notification_recipients.is_read IS 'Boolean flag indicating if the user has read this notification';
COMMENT ON COLUMN public.notification_recipients.read_at IS 'Timestamp when the notification was marked as read';
COMMENT ON COLUMN public.notification_recipients.is_dismissed IS 'Boolean flag indicating if the user has dismissed this notification';
COMMENT ON COLUMN public.notification_recipients.dismissed_at IS 'Timestamp when the notification was dismissed';
COMMENT ON COLUMN public.notification_recipients.created_at IS 'Timestamp when the recipient record was created';
COMMENT ON COLUMN public.notification_recipients.updated_at IS 'Timestamp when the recipient record was last updated (auto-updated)';

-- Index comments
COMMENT ON INDEX idx_notification_recipients_user_id IS 'Performance index for user-based notification queries';
COMMENT ON INDEX idx_notification_recipients_unread IS 'Partial index for efficient unread notification queries per user';
COMMENT ON INDEX idx_notification_recipients_notification_id IS 'Performance index for notification-based recipient queries';
COMMENT ON INDEX idx_notification_recipients_role IS 'Partial index for role-based notification targeting';
COMMENT ON INDEX idx_notification_recipients_branch IS 'Partial index for branch-based notification targeting';
COMMENT ON INDEX idx_notification_recipients_user_status IS 'Composite index for efficient user notification dashboard queries';