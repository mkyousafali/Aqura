-- ================================================================
-- TABLE SCHEMA: quick_task_assignments
-- Generated: 2025-11-06T11:09:39.017Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.quick_task_assignments (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    quick_task_id uuid NOT NULL,
    assigned_to_user_id uuid NOT NULL,
    status character varying DEFAULT 'pending'::character varying,
    accepted_at timestamp with time zone,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    require_task_finished boolean DEFAULT true,
    require_photo_upload boolean DEFAULT false,
    require_erp_reference boolean DEFAULT false
);

-- Table comment
COMMENT ON TABLE public.quick_task_assignments IS 'Table for quick task assignments management';

-- Column comments
COMMENT ON COLUMN public.quick_task_assignments.id IS 'Primary key identifier';
COMMENT ON COLUMN public.quick_task_assignments.quick_task_id IS 'Foreign key reference to quick_task table';
COMMENT ON COLUMN public.quick_task_assignments.assigned_to_user_id IS 'Foreign key reference to assigned_to_user table';
COMMENT ON COLUMN public.quick_task_assignments.status IS 'Status indicator';
COMMENT ON COLUMN public.quick_task_assignments.accepted_at IS 'accepted at field';
COMMENT ON COLUMN public.quick_task_assignments.started_at IS 'started at field';
COMMENT ON COLUMN public.quick_task_assignments.completed_at IS 'completed at field';
COMMENT ON COLUMN public.quick_task_assignments.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.quick_task_assignments.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.quick_task_assignments.require_task_finished IS 'Boolean flag';
COMMENT ON COLUMN public.quick_task_assignments.require_photo_upload IS 'Boolean flag';
COMMENT ON COLUMN public.quick_task_assignments.require_erp_reference IS 'Boolean flag';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS quick_task_assignments_pkey ON public.quick_task_assignments USING btree (id);

-- Foreign key index for quick_task_id
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_quick_task_id ON public.quick_task_assignments USING btree (quick_task_id);

-- Foreign key index for assigned_to_user_id
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_assigned_to_user_id ON public.quick_task_assignments USING btree (assigned_to_user_id);

-- Date index for accepted_at
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_accepted_at ON public.quick_task_assignments USING btree (accepted_at);

-- Date index for started_at
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_started_at ON public.quick_task_assignments USING btree (started_at);

-- Date index for completed_at
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_completed_at ON public.quick_task_assignments USING btree (completed_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for quick_task_assignments

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.quick_task_assignments ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "quick_task_assignments_select_policy" ON public.quick_task_assignments
    FOR SELECT USING (true);

CREATE POLICY "quick_task_assignments_insert_policy" ON public.quick_task_assignments
    FOR INSERT WITH CHECK (true);

CREATE POLICY "quick_task_assignments_update_policy" ON public.quick_task_assignments
    FOR UPDATE USING (true);

CREATE POLICY "quick_task_assignments_delete_policy" ON public.quick_task_assignments
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for quick_task_assignments

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.quick_task_assignments (quick_task_id, assigned_to_user_id, status)
VALUES ('uuid-example', 'uuid-example', 'example');
*/

-- Select example
/*
SELECT * FROM public.quick_task_assignments 
WHERE quick_task_id = $1;
*/

-- Update example
/*
UPDATE public.quick_task_assignments 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF QUICK_TASK_ASSIGNMENTS SCHEMA
-- ================================================================
