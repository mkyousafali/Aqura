-- ================================================================
-- TABLE SCHEMA: quick_task_completions
-- Generated: 2025-11-06T11:09:39.018Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.quick_task_completions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    quick_task_id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    completed_by_user_id uuid NOT NULL,
    completion_notes text,
    photo_path text,
    erp_reference character varying,
    completion_status character varying NOT NULL DEFAULT 'submitted'::character varying,
    verified_by_user_id uuid,
    verified_at timestamp with time zone,
    verification_notes text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.quick_task_completions IS 'Table for quick task completions management';

-- Column comments
COMMENT ON COLUMN public.quick_task_completions.id IS 'Primary key identifier';
COMMENT ON COLUMN public.quick_task_completions.quick_task_id IS 'Foreign key reference to quick_task table';
COMMENT ON COLUMN public.quick_task_completions.assignment_id IS 'Foreign key reference to assignment table';
COMMENT ON COLUMN public.quick_task_completions.completed_by_user_id IS 'Foreign key reference to completed_by_user table';
COMMENT ON COLUMN public.quick_task_completions.completion_notes IS 'Additional notes or comments';
COMMENT ON COLUMN public.quick_task_completions.photo_path IS 'photo path field';
COMMENT ON COLUMN public.quick_task_completions.erp_reference IS 'erp reference field';
COMMENT ON COLUMN public.quick_task_completions.completion_status IS 'Status indicator';
COMMENT ON COLUMN public.quick_task_completions.verified_by_user_id IS 'Foreign key reference to verified_by_user table';
COMMENT ON COLUMN public.quick_task_completions.verified_at IS 'verified at field';
COMMENT ON COLUMN public.quick_task_completions.verification_notes IS 'Additional notes or comments';
COMMENT ON COLUMN public.quick_task_completions.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.quick_task_completions.updated_at IS 'Timestamp when record was last updated';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS quick_task_completions_pkey ON public.quick_task_completions USING btree (id);

-- Foreign key index for quick_task_id
CREATE INDEX IF NOT EXISTS idx_quick_task_completions_quick_task_id ON public.quick_task_completions USING btree (quick_task_id);

-- Foreign key index for assignment_id
CREATE INDEX IF NOT EXISTS idx_quick_task_completions_assignment_id ON public.quick_task_completions USING btree (assignment_id);

-- Foreign key index for completed_by_user_id
CREATE INDEX IF NOT EXISTS idx_quick_task_completions_completed_by_user_id ON public.quick_task_completions USING btree (completed_by_user_id);

-- Foreign key index for verified_by_user_id
CREATE INDEX IF NOT EXISTS idx_quick_task_completions_verified_by_user_id ON public.quick_task_completions USING btree (verified_by_user_id);

-- Date index for verified_at
CREATE INDEX IF NOT EXISTS idx_quick_task_completions_verified_at ON public.quick_task_completions USING btree (verified_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for quick_task_completions

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.quick_task_completions ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "quick_task_completions_select_policy" ON public.quick_task_completions
    FOR SELECT USING (true);

CREATE POLICY "quick_task_completions_insert_policy" ON public.quick_task_completions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "quick_task_completions_update_policy" ON public.quick_task_completions
    FOR UPDATE USING (true);

CREATE POLICY "quick_task_completions_delete_policy" ON public.quick_task_completions
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for quick_task_completions

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.quick_task_completions (quick_task_id, assignment_id, completed_by_user_id)
VALUES ('uuid-example', 'uuid-example', 'uuid-example');
*/

-- Select example
/*
SELECT * FROM public.quick_task_completions 
WHERE quick_task_id = $1;
*/

-- Update example
/*
UPDATE public.quick_task_completions 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF QUICK_TASK_COMPLETIONS SCHEMA
-- ================================================================
