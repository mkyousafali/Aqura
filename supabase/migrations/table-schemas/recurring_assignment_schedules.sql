-- ================================================================
-- TABLE SCHEMA: recurring_assignment_schedules
-- Generated: 2025-11-06T11:09:39.021Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.recurring_assignment_schedules (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    assignment_id uuid NOT NULL,
    repeat_type text NOT NULL,
    repeat_interval integer NOT NULL DEFAULT 1,
    repeat_on_days ARRAY,
    repeat_on_date integer,
    repeat_on_month integer,
    execute_time time without time zone NOT NULL DEFAULT '09:00:00'::time without time zone,
    timezone text DEFAULT 'UTC'::text,
    start_date date NOT NULL,
    end_date date,
    max_occurrences integer,
    is_active boolean DEFAULT true,
    last_executed_at timestamp with time zone,
    next_execution_at timestamp with time zone NOT NULL,
    executions_count integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by text NOT NULL
);

-- Table comment
COMMENT ON TABLE public.recurring_assignment_schedules IS 'Table for recurring assignment schedules management';

-- Column comments
COMMENT ON COLUMN public.recurring_assignment_schedules.id IS 'Primary key identifier';
COMMENT ON COLUMN public.recurring_assignment_schedules.assignment_id IS 'Foreign key reference to assignment table';
COMMENT ON COLUMN public.recurring_assignment_schedules.repeat_type IS 'repeat type field';
COMMENT ON COLUMN public.recurring_assignment_schedules.repeat_interval IS 'repeat interval field';
COMMENT ON COLUMN public.recurring_assignment_schedules.repeat_on_days IS 'repeat on days field';
COMMENT ON COLUMN public.recurring_assignment_schedules.repeat_on_date IS 'Date field';
COMMENT ON COLUMN public.recurring_assignment_schedules.repeat_on_month IS 'repeat on month field';
COMMENT ON COLUMN public.recurring_assignment_schedules.execute_time IS 'execute time field';
COMMENT ON COLUMN public.recurring_assignment_schedules.timezone IS 'timezone field';
COMMENT ON COLUMN public.recurring_assignment_schedules.start_date IS 'Date field';
COMMENT ON COLUMN public.recurring_assignment_schedules.end_date IS 'Date field';
COMMENT ON COLUMN public.recurring_assignment_schedules.max_occurrences IS 'max occurrences field';
COMMENT ON COLUMN public.recurring_assignment_schedules.is_active IS 'Boolean flag';
COMMENT ON COLUMN public.recurring_assignment_schedules.last_executed_at IS 'last executed at field';
COMMENT ON COLUMN public.recurring_assignment_schedules.next_execution_at IS 'next execution at field';
COMMENT ON COLUMN public.recurring_assignment_schedules.executions_count IS 'executions count field';
COMMENT ON COLUMN public.recurring_assignment_schedules.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.recurring_assignment_schedules.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.recurring_assignment_schedules.created_by IS 'created by field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS recurring_assignment_schedules_pkey ON public.recurring_assignment_schedules USING btree (id);

-- Foreign key index for assignment_id
CREATE INDEX IF NOT EXISTS idx_recurring_assignment_schedules_assignment_id ON public.recurring_assignment_schedules USING btree (assignment_id);

-- Date index for start_date
CREATE INDEX IF NOT EXISTS idx_recurring_assignment_schedules_start_date ON public.recurring_assignment_schedules USING btree (start_date);

-- Date index for end_date
CREATE INDEX IF NOT EXISTS idx_recurring_assignment_schedules_end_date ON public.recurring_assignment_schedules USING btree (end_date);

-- Date index for last_executed_at
CREATE INDEX IF NOT EXISTS idx_recurring_assignment_schedules_last_executed_at ON public.recurring_assignment_schedules USING btree (last_executed_at);

-- Date index for next_execution_at
CREATE INDEX IF NOT EXISTS idx_recurring_assignment_schedules_next_execution_at ON public.recurring_assignment_schedules USING btree (next_execution_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for recurring_assignment_schedules

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.recurring_assignment_schedules ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "recurring_assignment_schedules_select_policy" ON public.recurring_assignment_schedules
    FOR SELECT USING (true);

CREATE POLICY "recurring_assignment_schedules_insert_policy" ON public.recurring_assignment_schedules
    FOR INSERT WITH CHECK (true);

CREATE POLICY "recurring_assignment_schedules_update_policy" ON public.recurring_assignment_schedules
    FOR UPDATE USING (true);

CREATE POLICY "recurring_assignment_schedules_delete_policy" ON public.recurring_assignment_schedules
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for recurring_assignment_schedules

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.recurring_assignment_schedules (assignment_id, repeat_type, repeat_interval)
VALUES ('uuid-example', 'example text', 123);
*/

-- Select example
/*
SELECT * FROM public.recurring_assignment_schedules 
WHERE assignment_id = $1;
*/

-- Update example
/*
UPDATE public.recurring_assignment_schedules 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF RECURRING_ASSIGNMENT_SCHEDULES SCHEMA
-- ================================================================
