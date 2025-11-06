-- ================================================================
-- TABLE SCHEMA: hr_employees
-- Generated: 2025-11-06T11:09:39.011Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.hr_employees (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    employee_id character varying NOT NULL,
    branch_id bigint NOT NULL,
    hire_date date,
    status character varying DEFAULT 'active'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    name character varying NOT NULL
);

-- Table comment
COMMENT ON TABLE public.hr_employees IS 'Table for hr employees management';

-- Column comments
COMMENT ON COLUMN public.hr_employees.id IS 'Primary key identifier';
COMMENT ON COLUMN public.hr_employees.employee_id IS 'Foreign key reference to employee table';
COMMENT ON COLUMN public.hr_employees.branch_id IS 'Foreign key reference to branch table';
COMMENT ON COLUMN public.hr_employees.hire_date IS 'Date field';
COMMENT ON COLUMN public.hr_employees.status IS 'Status indicator';
COMMENT ON COLUMN public.hr_employees.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.hr_employees.name IS 'Name field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS hr_employees_pkey ON public.hr_employees USING btree (id);

-- Foreign key index for employee_id
CREATE INDEX IF NOT EXISTS idx_hr_employees_employee_id ON public.hr_employees USING btree (employee_id);

-- Foreign key index for branch_id
CREATE INDEX IF NOT EXISTS idx_hr_employees_branch_id ON public.hr_employees USING btree (branch_id);

-- Date index for hire_date
CREATE INDEX IF NOT EXISTS idx_hr_employees_hire_date ON public.hr_employees USING btree (hire_date);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for hr_employees

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.hr_employees ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "hr_employees_select_policy" ON public.hr_employees
    FOR SELECT USING (true);

CREATE POLICY "hr_employees_insert_policy" ON public.hr_employees
    FOR INSERT WITH CHECK (true);

CREATE POLICY "hr_employees_update_policy" ON public.hr_employees
    FOR UPDATE USING (true);

CREATE POLICY "hr_employees_delete_policy" ON public.hr_employees
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for hr_employees

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.hr_employees (employee_id, branch_id, hire_date)
VALUES ('example', 'example', '2025-11-06');
*/

-- Select example
/*
SELECT * FROM public.hr_employees 
WHERE employee_id = $1;
*/

-- Update example
/*
UPDATE public.hr_employees 
SET name = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF HR_EMPLOYEES SCHEMA
-- ================================================================
