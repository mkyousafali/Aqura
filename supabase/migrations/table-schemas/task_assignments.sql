-- ================================================================
-- TABLE SCHEMA: task_assignments
-- Generated: 2025-11-06T11:09:39.022Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.task_assignments (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    task_id uuid NOT NULL,
    assignment_type text NOT NULL,
    assigned_to_user_id uuid,
    assigned_to_branch_id bigint,
    assigned_by uuid NOT NULL,
    assigned_by_name text,
    assigned_at timestamp with time zone DEFAULT now(),
    status text DEFAULT 'assigned'::text,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    schedule_date date,
    schedule_time time without time zone,
    deadline_date date,
    deadline_time time without time zone,
    deadline_datetime timestamp with time zone,
    is_reassignable boolean DEFAULT true,
    is_recurring boolean DEFAULT false,
    recurring_pattern jsonb,
    notes text,
    priority_override text,
    require_task_finished boolean DEFAULT true,
    require_photo_upload boolean DEFAULT false,
    require_erp_reference boolean DEFAULT false,
    reassigned_from uuid,
    reassignment_reason text,
    reassigned_at timestamp with time zone
);

-- Table comment
COMMENT ON TABLE public.task_assignments IS 'Table for task assignments management';

-- Column comments
COMMENT ON COLUMN public.task_assignments.id IS 'Primary key identifier';
COMMENT ON COLUMN public.task_assignments.task_id IS 'Foreign key reference to task table';
COMMENT ON COLUMN public.task_assignments.assignment_type IS 'assignment type field';
COMMENT ON COLUMN public.task_assignments.assigned_to_user_id IS 'Foreign key reference to assigned_to_user table';
COMMENT ON COLUMN public.task_assignments.assigned_to_branch_id IS 'Foreign key reference to assigned_to_branch table';
COMMENT ON COLUMN public.task_assignments.assigned_by IS 'assigned by field';
COMMENT ON COLUMN public.task_assignments.assigned_by_name IS 'Name field';
COMMENT ON COLUMN public.task_assignments.assigned_at IS 'assigned at field';
COMMENT ON COLUMN public.task_assignments.status IS 'Status indicator';
COMMENT ON COLUMN public.task_assignments.started_at IS 'started at field';
COMMENT ON COLUMN public.task_assignments.completed_at IS 'completed at field';
COMMENT ON COLUMN public.task_assignments.schedule_date IS 'Date field';
COMMENT ON COLUMN public.task_assignments.schedule_time IS 'schedule time field';
COMMENT ON COLUMN public.task_assignments.deadline_date IS 'Date field';
COMMENT ON COLUMN public.task_assignments.deadline_time IS 'deadline time field';
COMMENT ON COLUMN public.task_assignments.deadline_datetime IS 'Date field';
COMMENT ON COLUMN public.task_assignments.is_reassignable IS 'Boolean flag';
COMMENT ON COLUMN public.task_assignments.is_recurring IS 'Boolean flag';
COMMENT ON COLUMN public.task_assignments.recurring_pattern IS 'JSON data structure';
COMMENT ON COLUMN public.task_assignments.notes IS 'Additional notes or comments';
COMMENT ON COLUMN public.task_assignments.priority_override IS 'priority override field';
COMMENT ON COLUMN public.task_assignments.require_task_finished IS 'Boolean flag';
COMMENT ON COLUMN public.task_assignments.require_photo_upload IS 'Boolean flag';
COMMENT ON COLUMN public.task_assignments.require_erp_reference IS 'Boolean flag';
COMMENT ON COLUMN public.task_assignments.reassigned_from IS 'reassigned from field';
COMMENT ON COLUMN public.task_assignments.reassignment_reason IS 'reassignment reason field';
COMMENT ON COLUMN public.task_assignments.reassigned_at IS 'reassigned at field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS task_assignments_pkey ON public.task_assignments USING btree (id);

-- Foreign key index for task_id
CREATE INDEX IF NOT EXISTS idx_task_assignments_task_id ON public.task_assignments USING btree (task_id);

-- Foreign key index for assigned_to_user_id
CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_to_user_id ON public.task_assignments USING btree (assigned_to_user_id);

-- Foreign key index for assigned_to_branch_id
CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_to_branch_id ON public.task_assignments USING btree (assigned_to_branch_id);

-- Date index for assigned_at
CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_at ON public.task_assignments USING btree (assigned_at);

-- Date index for started_at
CREATE INDEX IF NOT EXISTS idx_task_assignments_started_at ON public.task_assignments USING btree (started_at);

-- Date index for completed_at
CREATE INDEX IF NOT EXISTS idx_task_assignments_completed_at ON public.task_assignments USING btree (completed_at);

-- Date index for schedule_date
CREATE INDEX IF NOT EXISTS idx_task_assignments_schedule_date ON public.task_assignments USING btree (schedule_date);

-- Date index for deadline_date
CREATE INDEX IF NOT EXISTS idx_task_assignments_deadline_date ON public.task_assignments USING btree (deadline_date);

-- Date index for deadline_datetime
CREATE INDEX IF NOT EXISTS idx_task_assignments_deadline_datetime ON public.task_assignments USING btree (deadline_datetime);

-- Date index for reassigned_at
CREATE INDEX IF NOT EXISTS idx_task_assignments_reassigned_at ON public.task_assignments USING btree (reassigned_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for task_assignments

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.task_assignments ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "task_assignments_select_policy" ON public.task_assignments
    FOR SELECT USING (true);

CREATE POLICY "task_assignments_insert_policy" ON public.task_assignments
    FOR INSERT WITH CHECK (true);

CREATE POLICY "task_assignments_update_policy" ON public.task_assignments
    FOR UPDATE USING (true);

CREATE POLICY "task_assignments_delete_policy" ON public.task_assignments
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for task_assignments

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.task_assignments (task_id, assignment_type, assigned_to_user_id)
VALUES ('uuid-example', 'example text', 'uuid-example');
*/

-- Select example
/*
SELECT * FROM public.task_assignments 
WHERE task_id = $1;
*/

-- Update example
/*
UPDATE public.task_assignments 
SET reassigned_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF TASK_ASSIGNMENTS SCHEMA
-- ================================================================
