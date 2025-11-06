-- ================================================================
-- TABLE SCHEMA: hr_salary_components
-- Generated: 2025-11-06T11:09:39.013Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.hr_salary_components (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    salary_id uuid NOT NULL,
    employee_id uuid NOT NULL,
    component_type character varying NOT NULL,
    component_name character varying NOT NULL,
    amount numeric NOT NULL,
    is_enabled boolean DEFAULT true,
    application_type character varying,
    single_month character varying,
    start_month character varying,
    end_month character varying,
    created_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.hr_salary_components IS 'Table for hr salary components management';

-- Column comments
COMMENT ON COLUMN public.hr_salary_components.id IS 'Primary key identifier';
COMMENT ON COLUMN public.hr_salary_components.salary_id IS 'Foreign key reference to salary table';
COMMENT ON COLUMN public.hr_salary_components.employee_id IS 'Foreign key reference to employee table';
COMMENT ON COLUMN public.hr_salary_components.component_type IS 'component type field';
COMMENT ON COLUMN public.hr_salary_components.component_name IS 'Name field';
COMMENT ON COLUMN public.hr_salary_components.amount IS 'Monetary amount';
COMMENT ON COLUMN public.hr_salary_components.is_enabled IS 'Boolean flag';
COMMENT ON COLUMN public.hr_salary_components.application_type IS 'application type field';
COMMENT ON COLUMN public.hr_salary_components.single_month IS 'single month field';
COMMENT ON COLUMN public.hr_salary_components.start_month IS 'start month field';
COMMENT ON COLUMN public.hr_salary_components.end_month IS 'end month field';
COMMENT ON COLUMN public.hr_salary_components.created_at IS 'Timestamp when record was created';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS hr_salary_components_pkey ON public.hr_salary_components USING btree (id);

-- Foreign key index for salary_id
CREATE INDEX IF NOT EXISTS idx_hr_salary_components_salary_id ON public.hr_salary_components USING btree (salary_id);

-- Foreign key index for employee_id
CREATE INDEX IF NOT EXISTS idx_hr_salary_components_employee_id ON public.hr_salary_components USING btree (employee_id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for hr_salary_components

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.hr_salary_components ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "hr_salary_components_select_policy" ON public.hr_salary_components
    FOR SELECT USING (true);

CREATE POLICY "hr_salary_components_insert_policy" ON public.hr_salary_components
    FOR INSERT WITH CHECK (true);

CREATE POLICY "hr_salary_components_update_policy" ON public.hr_salary_components
    FOR UPDATE USING (true);

CREATE POLICY "hr_salary_components_delete_policy" ON public.hr_salary_components
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for hr_salary_components

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.hr_salary_components (salary_id, employee_id, component_type)
VALUES ('uuid-example', 'uuid-example', 'example');
*/

-- Select example
/*
SELECT * FROM public.hr_salary_components 
WHERE salary_id = $1;
*/

-- Update example
/*
UPDATE public.hr_salary_components 
SET created_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF HR_SALARY_COMPONENTS SCHEMA
-- ================================================================
