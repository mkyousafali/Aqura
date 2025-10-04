-- Alternative Notifications Table Creation
-- Use this if the original table creation didn't work

-- Drop existing table if it exists (CAREFUL - this will delete data!)
DROP TABLE IF EXISTS public.notifications CASCADE;

-- Recreate notifications table with explicit column definitions
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) NOT NULL DEFAULT 'info',
    priority VARCHAR(20) NOT NULL DEFAULT 'medium',
    status VARCHAR(20) NOT NULL DEFAULT 'published',
    created_by VARCHAR(255) NOT NULL DEFAULT 'system',
    created_by_name VARCHAR(100) NOT NULL DEFAULT 'System',
    created_by_role VARCHAR(50) NOT NULL DEFAULT 'Admin',
    target_type VARCHAR(50) NOT NULL DEFAULT 'all_users',
    target_users JSONB NULL,
    target_roles JSONB NULL,
    target_branches JSONB NULL,
    scheduled_for TIMESTAMPTZ NULL,
    sent_at TIMESTAMPTZ NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NULL,
    has_attachments BOOLEAN NOT NULL DEFAULT false,
    read_count INTEGER NOT NULL DEFAULT 0,
    total_recipients INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ NULL,
    metadata JSONB NULL,
    task_id UUID NULL,
    task_assignment_id UUID NULL
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_priority ON public.notifications(priority);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON public.notifications(status);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_target_type ON public.notifications(target_type);

-- Add RLS policies (if needed)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Basic RLS policy (adjust based on your needs)
CREATE POLICY "Allow authenticated users to read notifications" ON public.notifications
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "Allow authenticated users to create notifications" ON public.notifications
    FOR INSERT TO authenticated
    WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update notifications" ON public.notifications
    FOR UPDATE TO authenticated
    USING (true);

-- Force schema cache refresh
NOTIFY pgrst, 'reload schema';