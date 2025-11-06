-- ================================================================
-- TABLE SCHEMA: task_images
-- Generated: 2025-11-06T11:09:39.023Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.task_images (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    task_id uuid NOT NULL,
    file_name text NOT NULL,
    file_size bigint NOT NULL,
    file_type text NOT NULL,
    file_url text NOT NULL,
    image_type text NOT NULL,
    uploaded_by text NOT NULL,
    uploaded_by_name text,
    created_at timestamp with time zone DEFAULT now(),
    image_width integer,
    image_height integer,
    file_path text,
    attachment_type text DEFAULT 'task_creation'::text
);

-- Table comment
COMMENT ON TABLE public.task_images IS 'Table for task images management';

-- Column comments
COMMENT ON COLUMN public.task_images.id IS 'Primary key identifier';
COMMENT ON COLUMN public.task_images.task_id IS 'Foreign key reference to task table';
COMMENT ON COLUMN public.task_images.file_name IS 'Name field';
COMMENT ON COLUMN public.task_images.file_size IS 'file size field';
COMMENT ON COLUMN public.task_images.file_type IS 'file type field';
COMMENT ON COLUMN public.task_images.file_url IS 'URL or file path';
COMMENT ON COLUMN public.task_images.image_type IS 'image type field';
COMMENT ON COLUMN public.task_images.uploaded_by IS 'uploaded by field';
COMMENT ON COLUMN public.task_images.uploaded_by_name IS 'Name field';
COMMENT ON COLUMN public.task_images.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.task_images.image_width IS 'image width field';
COMMENT ON COLUMN public.task_images.image_height IS 'image height field';
COMMENT ON COLUMN public.task_images.file_path IS 'file path field';
COMMENT ON COLUMN public.task_images.attachment_type IS 'attachment type field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS task_images_pkey ON public.task_images USING btree (id);

-- Foreign key index for task_id
CREATE INDEX IF NOT EXISTS idx_task_images_task_id ON public.task_images USING btree (task_id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for task_images

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.task_images ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "task_images_select_policy" ON public.task_images
    FOR SELECT USING (true);

CREATE POLICY "task_images_insert_policy" ON public.task_images
    FOR INSERT WITH CHECK (true);

CREATE POLICY "task_images_update_policy" ON public.task_images
    FOR UPDATE USING (true);

CREATE POLICY "task_images_delete_policy" ON public.task_images
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for task_images

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.task_images (task_id, file_name, file_size)
VALUES ('uuid-example', 'example text', 'example');
*/

-- Select example
/*
SELECT * FROM public.task_images 
WHERE task_id = $1;
*/

-- Update example
/*
UPDATE public.task_images 
SET attachment_type = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF TASK_IMAGES SCHEMA
-- ================================================================
