-- Migration for table: notifications
-- Generated on: 2025-10-30T21:55:45.332Z

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    title VARCHAR(255) NOT NULL,
    message VARCHAR(255) NOT NULL,
    created_by VARCHAR(255) NOT NULL,
    created_by_name VARCHAR(255) NOT NULL,
    created_by_role VARCHAR(255) NOT NULL,
    target_users JSONB NOT NULL,
    target_roles JSONB,
    target_branches JSONB,
    scheduled_for JSONB,
    sent_at TIMESTAMPTZ NOT NULL,
    expires_at JSONB,
    has_attachments BOOLEAN DEFAULT false NOT NULL,
    read_count NUMERIC NOT NULL,
    total_recipients NUMERIC NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ,
    metadata JSONB,
    task_id UUID,
    task_assignment_id JSONB,
    priority VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    target_type VARCHAR(50) NOT NULL,
    type VARCHAR(50) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_updated_at ON public.notifications(updated_at);
CREATE INDEX IF NOT EXISTS idx_notifications_deleted_at ON public.notifications(deleted_at);
CREATE INDEX IF NOT EXISTS idx_notifications_task_id ON public.notifications(task_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON public.notifications(status);
CREATE INDEX IF NOT EXISTS idx_notifications_target_type ON public.notifications(target_type);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications(type);

-- Enable Row Level Security
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_notifications_updated_at
    BEFORE UPDATE ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.notifications IS 'Generated from Aqura schema analysis';
