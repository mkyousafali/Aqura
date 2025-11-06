-- ================================================================
-- TABLE SCHEMA: quick_task_files
-- Generated: 2025-11-06T11:09:39.018Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.quick_task_files (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    quick_task_id uuid NOT NULL,
    file_name character varying NOT NULL,
    file_type character varying,
    file_size integer,
    mime_type character varying,
    storage_path text NOT NULL,
    storage_bucket character varying DEFAULT 'quick-task-files'::character varying,
    uploaded_by uuid,
    uploaded_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.quick_task_files IS 'Table for quick task files management';

-- Column comments
COMMENT ON COLUMN public.quick_task_files.id IS 'Primary key identifier';
COMMENT ON COLUMN public.quick_task_files.quick_task_id IS 'Foreign key reference to quick_task table';
COMMENT ON COLUMN public.quick_task_files.file_name IS 'Name field';
COMMENT ON COLUMN public.quick_task_files.file_type IS 'file type field';
COMMENT ON COLUMN public.quick_task_files.file_size IS 'file size field';
COMMENT ON COLUMN public.quick_task_files.mime_type IS 'mime type field';
COMMENT ON COLUMN public.quick_task_files.storage_path IS 'storage path field';
COMMENT ON COLUMN public.quick_task_files.storage_bucket IS 'storage bucket field';
COMMENT ON COLUMN public.quick_task_files.uploaded_by IS 'uploaded by field';
COMMENT ON COLUMN public.quick_task_files.uploaded_at IS 'uploaded at field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS quick_task_files_pkey ON public.quick_task_files USING btree (id);

-- Foreign key index for quick_task_id
CREATE INDEX IF NOT EXISTS idx_quick_task_files_quick_task_id ON public.quick_task_files USING btree (quick_task_id);

-- Date index for uploaded_at
CREATE INDEX IF NOT EXISTS idx_quick_task_files_uploaded_at ON public.quick_task_files USING btree (uploaded_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for quick_task_files

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.quick_task_files ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "quick_task_files_select_policy" ON public.quick_task_files
    FOR SELECT USING (true);

CREATE POLICY "quick_task_files_insert_policy" ON public.quick_task_files
    FOR INSERT WITH CHECK (true);

CREATE POLICY "quick_task_files_update_policy" ON public.quick_task_files
    FOR UPDATE USING (true);

CREATE POLICY "quick_task_files_delete_policy" ON public.quick_task_files
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for quick_task_files

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.quick_task_files (quick_task_id, file_name, file_type)
VALUES ('uuid-example', 'example', 'example');
*/

-- Select example
/*
SELECT * FROM public.quick_task_files 
WHERE quick_task_id = $1;
*/

-- Update example
/*
UPDATE public.quick_task_files 
SET uploaded_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF QUICK_TASK_FILES SCHEMA
-- ================================================================
