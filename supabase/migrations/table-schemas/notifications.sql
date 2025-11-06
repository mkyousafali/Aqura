-- ================================================================
-- TABLE SCHEMA: notifications
-- Generated: 2025-11-06T11:09:39.016Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    title character varying NOT NULL,
    message text NOT NULL,
    created_by character varying NOT NULL DEFAULT 'system'::character varying,
    created_by_name character varying NOT NULL DEFAULT 'System'::character varying,
    created_by_role character varying NOT NULL DEFAULT 'Admin'::character varying,
    target_users jsonb,
    target_roles jsonb,
    target_branches jsonb,
    scheduled_for timestamp with time zone,
    sent_at timestamp with time zone DEFAULT now(),
    expires_at timestamp with time zone,
    has_attachments boolean NOT NULL DEFAULT false,
    read_count integer NOT NULL DEFAULT 0,
    total_recipients integer NOT NULL DEFAULT 0,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    deleted_at timestamp with time zone,
    metadata jsonb,
    task_id uuid,
    task_assignment_id uuid,
    priority character varying NOT NULL DEFAULT 'medium'::character varying,
    status character varying NOT NULL DEFAULT 'published'::character varying,
    target_type character varying NOT NULL DEFAULT 'all_users'::character varying,
    type character varying NOT NULL DEFAULT 'info'::character varying
);

-- Table comment
COMMENT ON TABLE public.notifications IS 'Table for notifications management';

-- Column comments
COMMENT ON COLUMN public.notifications.id IS 'Primary key identifier';
COMMENT ON COLUMN public.notifications.title IS 'title field';
COMMENT ON COLUMN public.notifications.message IS 'message field';
COMMENT ON COLUMN public.notifications.created_by IS 'created by field';
COMMENT ON COLUMN public.notifications.created_by_name IS 'Name field';
COMMENT ON COLUMN public.notifications.created_by_role IS 'created by role field';
COMMENT ON COLUMN public.notifications.target_users IS 'JSON data structure';
COMMENT ON COLUMN public.notifications.target_roles IS 'JSON data structure';
COMMENT ON COLUMN public.notifications.target_branches IS 'JSON data structure';
COMMENT ON COLUMN public.notifications.scheduled_for IS 'scheduled for field';
COMMENT ON COLUMN public.notifications.sent_at IS 'sent at field';
COMMENT ON COLUMN public.notifications.expires_at IS 'expires at field';
COMMENT ON COLUMN public.notifications.has_attachments IS 'Boolean flag';
COMMENT ON COLUMN public.notifications.read_count IS 'read count field';
COMMENT ON COLUMN public.notifications.total_recipients IS 'total recipients field';
COMMENT ON COLUMN public.notifications.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.notifications.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.notifications.deleted_at IS 'deleted at field';
COMMENT ON COLUMN public.notifications.metadata IS 'JSON data structure';
COMMENT ON COLUMN public.notifications.task_id IS 'Foreign key reference to task table';
COMMENT ON COLUMN public.notifications.task_assignment_id IS 'Foreign key reference to task_assignment table';
COMMENT ON COLUMN public.notifications.priority IS 'priority field';
COMMENT ON COLUMN public.notifications.status IS 'Status indicator';
COMMENT ON COLUMN public.notifications.target_type IS 'target type field';
COMMENT ON COLUMN public.notifications.type IS 'type field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS notifications_pkey ON public.notifications USING btree (id);

-- Foreign key index for task_id
CREATE INDEX IF NOT EXISTS idx_notifications_task_id ON public.notifications USING btree (task_id);

-- Foreign key index for task_assignment_id
CREATE INDEX IF NOT EXISTS idx_notifications_task_assignment_id ON public.notifications USING btree (task_assignment_id);

-- Date index for scheduled_for
CREATE INDEX IF NOT EXISTS idx_notifications_scheduled_for ON public.notifications USING btree (scheduled_for);

-- Date index for sent_at
CREATE INDEX IF NOT EXISTS idx_notifications_sent_at ON public.notifications USING btree (sent_at);

-- Date index for expires_at
CREATE INDEX IF NOT EXISTS idx_notifications_expires_at ON public.notifications USING btree (expires_at);

-- Date index for deleted_at
CREATE INDEX IF NOT EXISTS idx_notifications_deleted_at ON public.notifications USING btree (deleted_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for notifications

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "notifications_select_policy" ON public.notifications
    FOR SELECT USING (true);

CREATE POLICY "notifications_insert_policy" ON public.notifications
    FOR INSERT WITH CHECK (true);

CREATE POLICY "notifications_update_policy" ON public.notifications
    FOR UPDATE USING (true);

CREATE POLICY "notifications_delete_policy" ON public.notifications
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for notifications

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.notifications (title, message, created_by)
VALUES ('example', 'example text', 'example');
*/

-- Select example
/*
SELECT * FROM public.notifications 
WHERE task_id = $1;
*/

-- Update example
/*
UPDATE public.notifications 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF NOTIFICATIONS SCHEMA
-- ================================================================
