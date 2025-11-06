-- ================================================================
-- TABLE SCHEMA: quick_task_comments
-- Generated: 2025-11-06T11:09:39.017Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.quick_task_comments (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    quick_task_id uuid NOT NULL,
    comment text NOT NULL,
    comment_type character varying DEFAULT 'comment'::character varying,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.quick_task_comments IS 'Table for quick task comments management';

-- Column comments
COMMENT ON COLUMN public.quick_task_comments.id IS 'Primary key identifier';
COMMENT ON COLUMN public.quick_task_comments.quick_task_id IS 'Foreign key reference to quick_task table';
COMMENT ON COLUMN public.quick_task_comments.comment IS 'comment field';
COMMENT ON COLUMN public.quick_task_comments.comment_type IS 'comment type field';
COMMENT ON COLUMN public.quick_task_comments.created_by IS 'created by field';
COMMENT ON COLUMN public.quick_task_comments.created_at IS 'Timestamp when record was created';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS quick_task_comments_pkey ON public.quick_task_comments USING btree (id);

-- Foreign key index for quick_task_id
CREATE INDEX IF NOT EXISTS idx_quick_task_comments_quick_task_id ON public.quick_task_comments USING btree (quick_task_id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for quick_task_comments

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.quick_task_comments ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "quick_task_comments_select_policy" ON public.quick_task_comments
    FOR SELECT USING (true);

CREATE POLICY "quick_task_comments_insert_policy" ON public.quick_task_comments
    FOR INSERT WITH CHECK (true);

CREATE POLICY "quick_task_comments_update_policy" ON public.quick_task_comments
    FOR UPDATE USING (true);

CREATE POLICY "quick_task_comments_delete_policy" ON public.quick_task_comments
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for quick_task_comments

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.quick_task_comments (quick_task_id, comment, comment_type)
VALUES ('uuid-example', 'example text', 'example');
*/

-- Select example
/*
SELECT * FROM public.quick_task_comments 
WHERE quick_task_id = $1;
*/

-- Update example
/*
UPDATE public.quick_task_comments 
SET created_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF QUICK_TASK_COMMENTS SCHEMA
-- ================================================================
