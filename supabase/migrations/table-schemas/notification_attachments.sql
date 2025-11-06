-- ================================================================
-- TABLE SCHEMA: notification_attachments
-- Generated: 2025-11-06T11:09:39.014Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.notification_attachments (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    notification_id uuid NOT NULL,
    file_name character varying NOT NULL,
    file_path text NOT NULL,
    file_size bigint NOT NULL,
    file_type character varying NOT NULL,
    uploaded_by character varying NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.notification_attachments IS 'Table for notification attachments management';

-- Column comments
COMMENT ON COLUMN public.notification_attachments.id IS 'Primary key identifier';
COMMENT ON COLUMN public.notification_attachments.notification_id IS 'Foreign key reference to notification table';
COMMENT ON COLUMN public.notification_attachments.file_name IS 'Name field';
COMMENT ON COLUMN public.notification_attachments.file_path IS 'file path field';
COMMENT ON COLUMN public.notification_attachments.file_size IS 'file size field';
COMMENT ON COLUMN public.notification_attachments.file_type IS 'file type field';
COMMENT ON COLUMN public.notification_attachments.uploaded_by IS 'uploaded by field';
COMMENT ON COLUMN public.notification_attachments.created_at IS 'Timestamp when record was created';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS notification_attachments_pkey ON public.notification_attachments USING btree (id);

-- Foreign key index for notification_id
CREATE INDEX IF NOT EXISTS idx_notification_attachments_notification_id ON public.notification_attachments USING btree (notification_id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for notification_attachments

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.notification_attachments ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "notification_attachments_select_policy" ON public.notification_attachments
    FOR SELECT USING (true);

CREATE POLICY "notification_attachments_insert_policy" ON public.notification_attachments
    FOR INSERT WITH CHECK (true);

CREATE POLICY "notification_attachments_update_policy" ON public.notification_attachments
    FOR UPDATE USING (true);

CREATE POLICY "notification_attachments_delete_policy" ON public.notification_attachments
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for notification_attachments

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.notification_attachments (notification_id, file_name, file_path)
VALUES ('uuid-example', 'example', 'example text');
*/

-- Select example
/*
SELECT * FROM public.notification_attachments 
WHERE notification_id = $1;
*/

-- Update example
/*
UPDATE public.notification_attachments 
SET created_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF NOTIFICATION_ATTACHMENTS SCHEMA
-- ================================================================
