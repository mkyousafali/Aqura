-- ================================================================
-- TABLE SCHEMA: notification_recipients
-- Generated: 2025-11-06T11:09:39.016Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.notification_recipients (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    notification_id uuid NOT NULL,
    role character varying,
    branch_id character varying,
    is_read boolean NOT NULL DEFAULT false,
    read_at timestamp with time zone,
    is_dismissed boolean NOT NULL DEFAULT false,
    dismissed_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    delivery_status character varying DEFAULT 'pending'::character varying,
    delivery_attempted_at timestamp with time zone,
    error_message text,
    user_id uuid
);

-- Table comment
COMMENT ON TABLE public.notification_recipients IS 'Table for notification recipients management';

-- Column comments
COMMENT ON COLUMN public.notification_recipients.id IS 'Primary key identifier';
COMMENT ON COLUMN public.notification_recipients.notification_id IS 'Foreign key reference to notification table';
COMMENT ON COLUMN public.notification_recipients.role IS 'role field';
COMMENT ON COLUMN public.notification_recipients.branch_id IS 'Foreign key reference to branch table';
COMMENT ON COLUMN public.notification_recipients.is_read IS 'Boolean flag';
COMMENT ON COLUMN public.notification_recipients.read_at IS 'read at field';
COMMENT ON COLUMN public.notification_recipients.is_dismissed IS 'Boolean flag';
COMMENT ON COLUMN public.notification_recipients.dismissed_at IS 'dismissed at field';
COMMENT ON COLUMN public.notification_recipients.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.notification_recipients.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.notification_recipients.delivery_status IS 'Status indicator';
COMMENT ON COLUMN public.notification_recipients.delivery_attempted_at IS 'delivery attempted at field';
COMMENT ON COLUMN public.notification_recipients.error_message IS 'error message field';
COMMENT ON COLUMN public.notification_recipients.user_id IS 'Foreign key reference to user table';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS notification_recipients_pkey ON public.notification_recipients USING btree (id);

-- Foreign key index for notification_id
CREATE INDEX IF NOT EXISTS idx_notification_recipients_notification_id ON public.notification_recipients USING btree (notification_id);

-- Foreign key index for branch_id
CREATE INDEX IF NOT EXISTS idx_notification_recipients_branch_id ON public.notification_recipients USING btree (branch_id);

-- Foreign key index for user_id
CREATE INDEX IF NOT EXISTS idx_notification_recipients_user_id ON public.notification_recipients USING btree (user_id);

-- Date index for read_at
CREATE INDEX IF NOT EXISTS idx_notification_recipients_read_at ON public.notification_recipients USING btree (read_at);

-- Date index for dismissed_at
CREATE INDEX IF NOT EXISTS idx_notification_recipients_dismissed_at ON public.notification_recipients USING btree (dismissed_at);

-- Date index for delivery_attempted_at
CREATE INDEX IF NOT EXISTS idx_notification_recipients_delivery_attempted_at ON public.notification_recipients USING btree (delivery_attempted_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for notification_recipients

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.notification_recipients ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "notification_recipients_select_policy" ON public.notification_recipients
    FOR SELECT USING (true);

CREATE POLICY "notification_recipients_insert_policy" ON public.notification_recipients
    FOR INSERT WITH CHECK (true);

CREATE POLICY "notification_recipients_update_policy" ON public.notification_recipients
    FOR UPDATE USING (true);

CREATE POLICY "notification_recipients_delete_policy" ON public.notification_recipients
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for notification_recipients

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.notification_recipients (notification_id, role, branch_id)
VALUES ('uuid-example', 'example', 'example');
*/

-- Select example
/*
SELECT * FROM public.notification_recipients 
WHERE notification_id = $1;
*/

-- Update example
/*
UPDATE public.notification_recipients 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF NOTIFICATION_RECIPIENTS SCHEMA
-- ================================================================
