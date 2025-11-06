-- ================================================================
-- TABLE SCHEMA: notification_read_states
-- Generated: 2025-11-06T11:09:39.015Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.notification_read_states (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    notification_id uuid NOT NULL,
    user_id text NOT NULL,
    read_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now(),
    is_read boolean NOT NULL DEFAULT false
);

-- Table comment
COMMENT ON TABLE public.notification_read_states IS 'Table for notification read states management';

-- Column comments
COMMENT ON COLUMN public.notification_read_states.id IS 'Primary key identifier';
COMMENT ON COLUMN public.notification_read_states.notification_id IS 'Foreign key reference to notification table';
COMMENT ON COLUMN public.notification_read_states.user_id IS 'Foreign key reference to user table';
COMMENT ON COLUMN public.notification_read_states.read_at IS 'read at field';
COMMENT ON COLUMN public.notification_read_states.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.notification_read_states.is_read IS 'Boolean flag';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS notification_read_states_pkey ON public.notification_read_states USING btree (id);

-- Foreign key index for notification_id
CREATE INDEX IF NOT EXISTS idx_notification_read_states_notification_id ON public.notification_read_states USING btree (notification_id);

-- Foreign key index for user_id
CREATE INDEX IF NOT EXISTS idx_notification_read_states_user_id ON public.notification_read_states USING btree (user_id);

-- Date index for read_at
CREATE INDEX IF NOT EXISTS idx_notification_read_states_read_at ON public.notification_read_states USING btree (read_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for notification_read_states

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.notification_read_states ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "notification_read_states_select_policy" ON public.notification_read_states
    FOR SELECT USING (true);

CREATE POLICY "notification_read_states_insert_policy" ON public.notification_read_states
    FOR INSERT WITH CHECK (true);

CREATE POLICY "notification_read_states_update_policy" ON public.notification_read_states
    FOR UPDATE USING (true);

CREATE POLICY "notification_read_states_delete_policy" ON public.notification_read_states
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for notification_read_states

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.notification_read_states (notification_id, user_id, read_at)
VALUES ('uuid-example', 'example text', '2025-11-06');
*/

-- Select example
/*
SELECT * FROM public.notification_read_states 
WHERE notification_id = $1;
*/

-- Update example
/*
UPDATE public.notification_read_states 
SET is_read = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF NOTIFICATION_READ_STATES SCHEMA
-- ================================================================
