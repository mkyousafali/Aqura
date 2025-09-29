-- =====================================================
-- Table: notifications
-- Description: Core notification system for managing all types of notifications
-- This table stores notification content, targeting, scheduling, and delivery status
-- =====================================================

-- Create enum types for notifications
CREATE TYPE public.notification_type_enum AS ENUM (
    'info',
    'warning', 
    'error',
    'success',
    'announcement',
    'task_assigned',
    'task_completed',
    'task_overdue',
    'system_maintenance',
    'policy_update',
    'birthday_reminder',
    'leave_approved',
    'leave_rejected',
    'document_uploaded',
    'meeting_scheduled'
);

CREATE TYPE public.notification_priority_enum AS ENUM (
    'low',
    'medium',
    'high',
    'urgent',
    'critical'
);

CREATE TYPE public.notification_status_enum AS ENUM (
    'draft',
    'scheduled',
    'published',
    'sent',
    'expired',
    'cancelled'
);

CREATE TYPE public.notification_target_type_enum AS ENUM (
    'all_users',
    'specific_users',
    'role_based',
    'branch_based',
    'department_based',
    'mixed_targeting'
);

-- Create notifications table
CREATE TABLE public.notifications (
    -- Primary key with UUID generation
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    
    -- Notification content
    title CHARACTER VARYING(255) NOT NULL,
    message TEXT NOT NULL,
    
    -- Classification and priority
    type public.notification_type_enum NOT NULL DEFAULT 'info'::notification_type_enum,
    priority public.notification_priority_enum NOT NULL DEFAULT 'medium'::notification_priority_enum,
    status public.notification_status_enum NOT NULL DEFAULT 'published'::notification_status_enum,
    
    -- Creator information
    created_by CHARACTER VARYING(255) NOT NULL DEFAULT 'system'::character varying,
    created_by_name CHARACTER VARYING(100) NOT NULL DEFAULT 'System'::character varying,
    created_by_role CHARACTER VARYING(50) NOT NULL DEFAULT 'Admin'::character varying,
    
    -- Targeting configuration
    target_type public.notification_target_type_enum NOT NULL DEFAULT 'all_users'::notification_target_type_enum,
    target_users JSONB NULL,
    target_roles JSONB NULL,
    target_branches JSONB NULL,
    
    -- Scheduling and delivery
    scheduled_for TIMESTAMP WITH TIME ZONE NULL,
    sent_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    expires_at TIMESTAMP WITH TIME ZONE NULL,
    
    -- Attachments and statistics
    has_attachments BOOLEAN NOT NULL DEFAULT false,
    read_count INTEGER NOT NULL DEFAULT 0,
    total_recipients INTEGER NOT NULL DEFAULT 0,
    
    -- Audit timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    deleted_at TIMESTAMP WITH TIME ZONE NULL,
    
    -- Primary key constraint
    CONSTRAINT notifications_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

-- =====================================================
-- Indexes for Performance Optimization
-- =====================================================

-- Basic classification indexes
CREATE INDEX IF NOT EXISTS idx_notifications_type 
    ON public.notifications 
    USING btree (type) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notifications_priority 
    ON public.notifications 
    USING btree (priority) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notifications_status 
    ON public.notifications 
    USING btree (status) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notifications_target_type 
    ON public.notifications 
    USING btree (target_type) 
    TABLESPACE pg_default;

-- Temporal indexes
CREATE INDEX IF NOT EXISTS idx_notifications_created_at 
    ON public.notifications 
    USING btree (created_at DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notifications_sent_at 
    ON public.notifications 
    USING btree (sent_at DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notifications_scheduled_for 
    ON public.notifications 
    USING btree (scheduled_for) 
    TABLESPACE pg_default
    WHERE scheduled_for IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_expires_at 
    ON public.notifications 
    USING btree (expires_at) 
    TABLESPACE pg_default
    WHERE expires_at IS NOT NULL;

-- Creator and soft delete indexes
CREATE INDEX IF NOT EXISTS idx_notifications_created_by 
    ON public.notifications 
    USING btree (created_by) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notifications_active 
    ON public.notifications 
    USING btree (status, created_at DESC) 
    TABLESPACE pg_default
    WHERE deleted_at IS NULL;

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_notifications_dashboard 
    ON public.notifications 
    USING btree (status, priority, created_at DESC) 
    TABLESPACE pg_default
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_active_by_type 
    ON public.notifications 
    USING btree (type, status, created_at DESC) 
    TABLESPACE pg_default
    WHERE deleted_at IS NULL;

-- JSONB indexes for targeting queries
CREATE INDEX IF NOT EXISTS idx_notifications_target_users_gin 
    ON public.notifications 
    USING gin (target_users) 
    TABLESPACE pg_default
    WHERE target_users IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_target_roles_gin 
    ON public.notifications 
    USING gin (target_roles) 
    TABLESPACE pg_default
    WHERE target_roles IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_target_branches_gin 
    ON public.notifications 
    USING gin (target_branches) 
    TABLESPACE pg_default
    WHERE target_branches IS NOT NULL;

-- =====================================================
-- Triggers for Automatic Updates
-- =====================================================

-- Create trigger function for updating updated_at timestamp
CREATE OR REPLACE FUNCTION update_notifications_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic timestamp updates
CREATE TRIGGER trigger_update_notifications_updated_at
    BEFORE UPDATE ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION update_notifications_updated_at();

-- Trigger for automatic read count and recipient calculations
CREATE OR REPLACE FUNCTION update_notification_statistics()
RETURNS TRIGGER AS $$
BEGIN
    -- Update read count when status changes to sent
    IF NEW.status = 'sent' AND OLD.status != 'sent' THEN
        NEW.sent_at = now();
    END IF;
    
    -- Auto-calculate total recipients based on target type
    IF NEW.target_type = 'all_users' THEN
        -- Would typically count from users table
        NEW.total_recipients = COALESCE(NEW.total_recipients, 0);
    ELSIF NEW.target_type = 'specific_users' AND NEW.target_users IS NOT NULL THEN
        NEW.total_recipients = jsonb_array_length(NEW.target_users);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for notification statistics
CREATE TRIGGER trigger_notification_statistics
    BEFORE INSERT OR UPDATE ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION update_notification_statistics();

-- =====================================================
-- Functions for Notification Management
-- =====================================================

-- Function to soft delete notifications
CREATE OR REPLACE FUNCTION soft_delete_notification(notification_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.notifications 
    SET deleted_at = now(), 
        status = 'cancelled'
    WHERE id = notification_uuid 
      AND deleted_at IS NULL;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to schedule notifications
CREATE OR REPLACE FUNCTION schedule_notification(
    notification_uuid UUID, 
    schedule_time TIMESTAMP WITH TIME ZONE
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.notifications 
    SET scheduled_for = schedule_time,
        status = 'scheduled'
    WHERE id = notification_uuid 
      AND deleted_at IS NULL;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to increment read count
CREATE OR REPLACE FUNCTION increment_notification_read_count(notification_uuid UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.notifications 
    SET read_count = read_count + 1
    WHERE id = notification_uuid;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Table Comments for Documentation
-- =====================================================

COMMENT ON TABLE public.notifications IS 'Core notification system storing all notification content, targeting, scheduling, and delivery status';

COMMENT ON COLUMN public.notifications.id IS 'Primary key - unique identifier for each notification';
COMMENT ON COLUMN public.notifications.title IS 'Notification title/subject (max 255 characters)';
COMMENT ON COLUMN public.notifications.message IS 'Full notification message content (unlimited text)';
COMMENT ON COLUMN public.notifications.type IS 'Notification category/type using enum (info, warning, error, success, etc.)';
COMMENT ON COLUMN public.notifications.priority IS 'Notification priority level using enum (low, medium, high, urgent, critical)';
COMMENT ON COLUMN public.notifications.status IS 'Current notification status using enum (draft, scheduled, published, sent, expired, cancelled)';
COMMENT ON COLUMN public.notifications.created_by IS 'User ID of notification creator';
COMMENT ON COLUMN public.notifications.created_by_name IS 'Display name of notification creator';
COMMENT ON COLUMN public.notifications.created_by_role IS 'Role of notification creator';
COMMENT ON COLUMN public.notifications.target_type IS 'Targeting strategy using enum (all_users, specific_users, role_based, branch_based, etc.)';
COMMENT ON COLUMN public.notifications.target_users IS 'JSONB array of specific user IDs when using specific_users targeting';
COMMENT ON COLUMN public.notifications.target_roles IS 'JSONB array of target roles when using role_based targeting';
COMMENT ON COLUMN public.notifications.target_branches IS 'JSONB array of target branches when using branch_based targeting';
COMMENT ON COLUMN public.notifications.scheduled_for IS 'Future timestamp for scheduled notifications';
COMMENT ON COLUMN public.notifications.sent_at IS 'Timestamp when notification was actually sent/published';
COMMENT ON COLUMN public.notifications.expires_at IS 'Expiration timestamp for time-sensitive notifications';
COMMENT ON COLUMN public.notifications.has_attachments IS 'Boolean flag indicating if notification has file attachments';
COMMENT ON COLUMN public.notifications.read_count IS 'Count of users who have read this notification';
COMMENT ON COLUMN public.notifications.total_recipients IS 'Total number of intended recipients';
COMMENT ON COLUMN public.notifications.created_at IS 'Timestamp when notification was created';
COMMENT ON COLUMN public.notifications.updated_at IS 'Timestamp when notification was last updated (auto-updated)';
COMMENT ON COLUMN public.notifications.deleted_at IS 'Soft delete timestamp (NULL = active notification)';

-- Enum comments
COMMENT ON TYPE public.notification_type_enum IS 'Enumeration of notification types for categorization';
COMMENT ON TYPE public.notification_priority_enum IS 'Enumeration of priority levels for notification importance';
COMMENT ON TYPE public.notification_status_enum IS 'Enumeration of notification lifecycle states';
COMMENT ON TYPE public.notification_target_type_enum IS 'Enumeration of targeting strategies for notification delivery';

-- Index comments
COMMENT ON INDEX idx_notifications_type IS 'Performance index for notification type filtering';
COMMENT ON INDEX idx_notifications_priority IS 'Performance index for priority-based queries';
COMMENT ON INDEX idx_notifications_status IS 'Performance index for status filtering';
COMMENT ON INDEX idx_notifications_dashboard IS 'Composite index for notification dashboard queries';
COMMENT ON INDEX idx_notifications_target_users_gin IS 'GIN index for JSONB user targeting queries';
COMMENT ON INDEX idx_notifications_active IS 'Partial index for active (non-deleted) notifications';