-- ================================================================
-- TABLE SCHEMA: task_completions
-- Generated: 2025-11-06T11:09:39.022Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.task_completions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    task_id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    completed_by text NOT NULL,
    completed_by_name text,
    completed_by_branch_id uuid,
    task_finished_completed boolean DEFAULT false,
    photo_uploaded_completed boolean DEFAULT false,
    erp_reference_completed boolean DEFAULT false,
    erp_reference_number text,
    completion_notes text,
    verified_by text,
    verified_at timestamp with time zone,
    verification_notes text,
    completed_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now(),
    completion_photo_url text
);

-- Table comment
COMMENT ON TABLE public.task_completions IS 'Table for task completions management';

-- Column comments
COMMENT ON COLUMN public.task_completions.id IS 'Primary key identifier';
COMMENT ON COLUMN public.task_completions.task_id IS 'Foreign key reference to task table';
COMMENT ON COLUMN public.task_completions.assignment_id IS 'Foreign key reference to assignment table';
COMMENT ON COLUMN public.task_completions.completed_by IS 'completed by field';
COMMENT ON COLUMN public.task_completions.completed_by_name IS 'Name field';
COMMENT ON COLUMN public.task_completions.completed_by_branch_id IS 'Foreign key reference to completed_by_branch table';
COMMENT ON COLUMN public.task_completions.task_finished_completed IS 'Boolean flag';
COMMENT ON COLUMN public.task_completions.photo_uploaded_completed IS 'Boolean flag';
COMMENT ON COLUMN public.task_completions.erp_reference_completed IS 'Boolean flag';
COMMENT ON COLUMN public.task_completions.erp_reference_number IS 'Reference number';
COMMENT ON COLUMN public.task_completions.completion_notes IS 'Additional notes or comments';
COMMENT ON COLUMN public.task_completions.verified_by IS 'verified by field';
COMMENT ON COLUMN public.task_completions.verified_at IS 'verified at field';
COMMENT ON COLUMN public.task_completions.verification_notes IS 'Additional notes or comments';
COMMENT ON COLUMN public.task_completions.completed_at IS 'completed at field';
COMMENT ON COLUMN public.task_completions.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.task_completions.completion_photo_url IS 'URL or file path';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS task_completions_pkey ON public.task_completions USING btree (id);

-- Foreign key index for task_id
CREATE INDEX IF NOT EXISTS idx_task_completions_task_id ON public.task_completions USING btree (task_id);

-- Foreign key index for assignment_id
CREATE INDEX IF NOT EXISTS idx_task_completions_assignment_id ON public.task_completions USING btree (assignment_id);

-- Foreign key index for completed_by_branch_id
CREATE INDEX IF NOT EXISTS idx_task_completions_completed_by_branch_id ON public.task_completions USING btree (completed_by_branch_id);

-- Date index for verified_at
CREATE INDEX IF NOT EXISTS idx_task_completions_verified_at ON public.task_completions USING btree (verified_at);

-- Date index for completed_at
CREATE INDEX IF NOT EXISTS idx_task_completions_completed_at ON public.task_completions USING btree (completed_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for task_completions

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.task_completions ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "task_completions_select_policy" ON public.task_completions
    FOR SELECT USING (true);

CREATE POLICY "task_completions_insert_policy" ON public.task_completions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "task_completions_update_policy" ON public.task_completions
    FOR UPDATE USING (true);

CREATE POLICY "task_completions_delete_policy" ON public.task_completions
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for task_completions

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.task_completions (task_id, assignment_id, completed_by)
VALUES ('uuid-example', 'uuid-example', 'example text');
*/

-- Select example
/*
SELECT * FROM public.task_completions 
WHERE task_id = $1;
*/

-- Update example
/*
UPDATE public.task_completions 
SET completion_photo_url = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF TASK_COMPLETIONS SCHEMA
-- ================================================================
