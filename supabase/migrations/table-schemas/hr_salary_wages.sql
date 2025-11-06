-- ================================================================
-- TABLE SCHEMA: hr_salary_wages
-- Generated: 2025-11-06T11:09:39.014Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.hr_salary_wages (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    employee_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    basic_salary numeric NOT NULL,
    effective_from date NOT NULL,
    is_current boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.hr_salary_wages IS 'Table for hr salary wages management';

-- Column comments
COMMENT ON COLUMN public.hr_salary_wages.id IS 'Primary key identifier';
COMMENT ON COLUMN public.hr_salary_wages.employee_id IS 'Foreign key reference to employee table';
COMMENT ON COLUMN public.hr_salary_wages.branch_id IS 'Foreign key reference to branch table';
COMMENT ON COLUMN public.hr_salary_wages.basic_salary IS 'basic salary field';
COMMENT ON COLUMN public.hr_salary_wages.effective_from IS 'effective from field';
COMMENT ON COLUMN public.hr_salary_wages.is_current IS 'Boolean flag';
COMMENT ON COLUMN public.hr_salary_wages.created_at IS 'Timestamp when record was created';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS hr_salary_wages_pkey ON public.hr_salary_wages USING btree (id);

-- Foreign key index for employee_id
CREATE INDEX IF NOT EXISTS idx_hr_salary_wages_employee_id ON public.hr_salary_wages USING btree (employee_id);

-- Foreign key index for branch_id
CREATE INDEX IF NOT EXISTS idx_hr_salary_wages_branch_id ON public.hr_salary_wages USING btree (branch_id);

-- Date index for effective_from
CREATE INDEX IF NOT EXISTS idx_hr_salary_wages_effective_from ON public.hr_salary_wages USING btree (effective_from);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for hr_salary_wages

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.hr_salary_wages ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "hr_salary_wages_select_policy" ON public.hr_salary_wages
    FOR SELECT USING (true);

CREATE POLICY "hr_salary_wages_insert_policy" ON public.hr_salary_wages
    FOR INSERT WITH CHECK (true);

CREATE POLICY "hr_salary_wages_update_policy" ON public.hr_salary_wages
    FOR UPDATE USING (true);

CREATE POLICY "hr_salary_wages_delete_policy" ON public.hr_salary_wages
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for hr_salary_wages

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.hr_salary_wages (employee_id, branch_id, basic_salary)
VALUES ('uuid-example', 'uuid-example', 123);
*/

-- Select example
/*
SELECT * FROM public.hr_salary_wages 
WHERE employee_id = $1;
*/

-- Update example
/*
UPDATE public.hr_salary_wages 
SET created_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF HR_SALARY_WAGES SCHEMA
-- ================================================================
