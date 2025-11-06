-- ================================================================
-- TABLE SCHEMA: hr_position_assignments
-- Generated: 2025-11-06T11:09:39.012Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.hr_position_assignments (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    employee_id uuid NOT NULL,
    position_id uuid NOT NULL,
    department_id uuid NOT NULL,
    level_id uuid NOT NULL,
    branch_id bigint NOT NULL,
    effective_date date NOT NULL DEFAULT CURRENT_DATE,
    is_current boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.hr_position_assignments IS 'Table for hr position assignments management';

-- Column comments
COMMENT ON COLUMN public.hr_position_assignments.id IS 'Primary key identifier';
COMMENT ON COLUMN public.hr_position_assignments.employee_id IS 'Foreign key reference to employee table';
COMMENT ON COLUMN public.hr_position_assignments.position_id IS 'Foreign key reference to position table';
COMMENT ON COLUMN public.hr_position_assignments.department_id IS 'Foreign key reference to department table';
COMMENT ON COLUMN public.hr_position_assignments.level_id IS 'Foreign key reference to level table';
COMMENT ON COLUMN public.hr_position_assignments.branch_id IS 'Foreign key reference to branch table';
COMMENT ON COLUMN public.hr_position_assignments.effective_date IS 'Date field';
COMMENT ON COLUMN public.hr_position_assignments.is_current IS 'Boolean flag';
COMMENT ON COLUMN public.hr_position_assignments.created_at IS 'Timestamp when record was created';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS hr_position_assignments_pkey ON public.hr_position_assignments USING btree (id);

-- Foreign key index for employee_id
CREATE INDEX IF NOT EXISTS idx_hr_position_assignments_employee_id ON public.hr_position_assignments USING btree (employee_id);

-- Foreign key index for position_id
CREATE INDEX IF NOT EXISTS idx_hr_position_assignments_position_id ON public.hr_position_assignments USING btree (position_id);

-- Foreign key index for department_id
CREATE INDEX IF NOT EXISTS idx_hr_position_assignments_department_id ON public.hr_position_assignments USING btree (department_id);

-- Foreign key index for level_id
CREATE INDEX IF NOT EXISTS idx_hr_position_assignments_level_id ON public.hr_position_assignments USING btree (level_id);

-- Foreign key index for branch_id
CREATE INDEX IF NOT EXISTS idx_hr_position_assignments_branch_id ON public.hr_position_assignments USING btree (branch_id);

-- Date index for effective_date
CREATE INDEX IF NOT EXISTS idx_hr_position_assignments_effective_date ON public.hr_position_assignments USING btree (effective_date);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for hr_position_assignments

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.hr_position_assignments ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "hr_position_assignments_select_policy" ON public.hr_position_assignments
    FOR SELECT USING (true);

CREATE POLICY "hr_position_assignments_insert_policy" ON public.hr_position_assignments
    FOR INSERT WITH CHECK (true);

CREATE POLICY "hr_position_assignments_update_policy" ON public.hr_position_assignments
    FOR UPDATE USING (true);

CREATE POLICY "hr_position_assignments_delete_policy" ON public.hr_position_assignments
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for hr_position_assignments

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.hr_position_assignments (employee_id, position_id, department_id)
VALUES ('uuid-example', 'uuid-example', 'uuid-example');
*/

-- Select example
/*
SELECT * FROM public.hr_position_assignments 
WHERE employee_id = $1;
*/

-- Update example
/*
UPDATE public.hr_position_assignments 
SET created_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF HR_POSITION_ASSIGNMENTS SCHEMA
-- ================================================================
