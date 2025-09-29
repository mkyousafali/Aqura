-- Table 13: HR Salary Wages
-- Purpose: Manages employee basic salary information with effective dates
-- Created: 2025-09-29

CREATE TABLE public.hr_salary_wages (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  employee_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  basic_salary numeric(12, 2) NOT NULL,
  effective_from date NOT NULL,
  is_current boolean NULL DEFAULT true,
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT hr_salary_wages_pkey PRIMARY KEY (id),
  CONSTRAINT hr_salary_wages_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr_employees (id)
) TABLESPACE pg_default;

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_hr_salary_employee_id 
  ON public.hr_salary_wages USING btree (employee_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_salary_branch_id 
  ON public.hr_salary_wages USING btree (branch_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_salary_effective_from 
  ON public.hr_salary_wages USING btree (effective_from) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_salary_current 
  ON public.hr_salary_wages USING btree (is_current) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_salary_employee_current 
  ON public.hr_salary_wages USING btree (employee_id, is_current) TABLESPACE pg_default;

-- Unique constraint to ensure only one current salary per employee
CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_salary_employee_current_unique 
  ON public.hr_salary_wages USING btree (employee_id) WHERE is_current = true;

-- Comments for documentation
COMMENT ON TABLE public.hr_salary_wages IS 'Employee basic salary records with effective dates and historical tracking';
COMMENT ON COLUMN public.hr_salary_wages.id IS 'Primary key - UUID generated automatically';
COMMENT ON COLUMN public.hr_salary_wages.employee_id IS 'Foreign key reference to hr_employees table (required)';
COMMENT ON COLUMN public.hr_salary_wages.branch_id IS 'Branch where salary is applicable (UUID reference)';
COMMENT ON COLUMN public.hr_salary_wages.basic_salary IS 'Basic salary amount (12,2 precision for accurate monetary values)';
COMMENT ON COLUMN public.hr_salary_wages.effective_from IS 'Date when this salary becomes effective (required)';
COMMENT ON COLUMN public.hr_salary_wages.is_current IS 'Whether this is the current active salary for the employee';
COMMENT ON COLUMN public.hr_salary_wages.created_at IS 'Timestamp when the record was created';