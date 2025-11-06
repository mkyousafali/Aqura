-- ================================================================
-- TABLE SCHEMA: quick_tasks
-- Generated: 2025-11-06T11:09:39.019Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.quick_tasks (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    title character varying NOT NULL,
    description text,
    price_tag character varying,
    issue_type character varying NOT NULL,
    priority character varying NOT NULL,
    assigned_by uuid NOT NULL,
    assigned_to_branch_id bigint,
    created_at timestamp with time zone DEFAULT now(),
    deadline_datetime timestamp with time zone DEFAULT (now() + '24:00:00'::interval),
    completed_at timestamp with time zone,
    status character varying DEFAULT 'pending'::character varying,
    created_from character varying DEFAULT 'quick_task'::character varying,
    updated_at timestamp with time zone DEFAULT now(),
    require_task_finished boolean DEFAULT true,
    require_photo_upload boolean DEFAULT false,
    require_erp_reference boolean DEFAULT false
);

-- Table comment
COMMENT ON TABLE public.quick_tasks IS 'Table for quick tasks management';

-- Column comments
COMMENT ON COLUMN public.quick_tasks.id IS 'Primary key identifier';
COMMENT ON COLUMN public.quick_tasks.title IS 'title field';
COMMENT ON COLUMN public.quick_tasks.description IS 'description field';
COMMENT ON COLUMN public.quick_tasks.price_tag IS 'price tag field';
COMMENT ON COLUMN public.quick_tasks.issue_type IS 'issue type field';
COMMENT ON COLUMN public.quick_tasks.priority IS 'priority field';
COMMENT ON COLUMN public.quick_tasks.assigned_by IS 'assigned by field';
COMMENT ON COLUMN public.quick_tasks.assigned_to_branch_id IS 'Foreign key reference to assigned_to_branch table';
COMMENT ON COLUMN public.quick_tasks.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.quick_tasks.deadline_datetime IS 'Date field';
COMMENT ON COLUMN public.quick_tasks.completed_at IS 'completed at field';
COMMENT ON COLUMN public.quick_tasks.status IS 'Status indicator';
COMMENT ON COLUMN public.quick_tasks.created_from IS 'created from field';
COMMENT ON COLUMN public.quick_tasks.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.quick_tasks.require_task_finished IS 'Boolean flag';
COMMENT ON COLUMN public.quick_tasks.require_photo_upload IS 'Boolean flag';
COMMENT ON COLUMN public.quick_tasks.require_erp_reference IS 'Boolean flag';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS quick_tasks_pkey ON public.quick_tasks USING btree (id);

-- Foreign key index for assigned_to_branch_id
CREATE INDEX IF NOT EXISTS idx_quick_tasks_assigned_to_branch_id ON public.quick_tasks USING btree (assigned_to_branch_id);

-- Date index for deadline_datetime
CREATE INDEX IF NOT EXISTS idx_quick_tasks_deadline_datetime ON public.quick_tasks USING btree (deadline_datetime);

-- Date index for completed_at
CREATE INDEX IF NOT EXISTS idx_quick_tasks_completed_at ON public.quick_tasks USING btree (completed_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for quick_tasks

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.quick_tasks ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "quick_tasks_select_policy" ON public.quick_tasks
    FOR SELECT USING (true);

CREATE POLICY "quick_tasks_insert_policy" ON public.quick_tasks
    FOR INSERT WITH CHECK (true);

CREATE POLICY "quick_tasks_update_policy" ON public.quick_tasks
    FOR UPDATE USING (true);

CREATE POLICY "quick_tasks_delete_policy" ON public.quick_tasks
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for quick_tasks

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.quick_tasks (title, description, price_tag)
VALUES ('example', 'example text', 'example');
*/

-- Select example
/*
SELECT * FROM public.quick_tasks 
WHERE assigned_to_branch_id = $1;
*/

-- Update example
/*
UPDATE public.quick_tasks 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF QUICK_TASKS SCHEMA
-- ================================================================
