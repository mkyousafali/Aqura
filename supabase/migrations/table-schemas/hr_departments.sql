-- ================================================================
-- TABLE SCHEMA: hr_departments
-- Generated: 2025-11-06T11:09:39.010Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.hr_departments (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    department_name_en character varying NOT NULL,
    department_name_ar character varying NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.hr_departments IS 'Table for hr departments management';

-- Column comments
COMMENT ON COLUMN public.hr_departments.id IS 'Primary key identifier';
COMMENT ON COLUMN public.hr_departments.department_name_en IS 'Name field';
COMMENT ON COLUMN public.hr_departments.department_name_ar IS 'Name field';
COMMENT ON COLUMN public.hr_departments.is_active IS 'Boolean flag';
COMMENT ON COLUMN public.hr_departments.created_at IS 'Timestamp when record was created';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS hr_departments_pkey ON public.hr_departments USING btree (id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for hr_departments

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.hr_departments ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "hr_departments_select_policy" ON public.hr_departments
    FOR SELECT USING (true);

CREATE POLICY "hr_departments_insert_policy" ON public.hr_departments
    FOR INSERT WITH CHECK (true);

CREATE POLICY "hr_departments_update_policy" ON public.hr_departments
    FOR UPDATE USING (true);

CREATE POLICY "hr_departments_delete_policy" ON public.hr_departments
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for hr_departments

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.hr_departments (department_name_en, department_name_ar, is_active)
VALUES ('example', 'example', true);
*/

-- Select example
/*
SELECT * FROM public.hr_departments 
WHERE id = $1;
*/

-- Update example
/*
UPDATE public.hr_departments 
SET created_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF HR_DEPARTMENTS SCHEMA
-- ================================================================
