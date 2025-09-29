-- Table 12: HR Salary Components
-- Purpose: Manages salary components (allowances/deductions) with flexible application periods
-- Created: 2025-09-29

CREATE TABLE public.hr_salary_components (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  salary_id uuid NOT NULL,
  employee_id uuid NOT NULL,
  component_type character varying(20) NOT NULL,
  component_name character varying(100) NOT NULL,
  amount numeric(12, 2) NOT NULL,
  is_enabled boolean NULL DEFAULT true,
  application_type character varying(20) NULL,
  single_month character varying(7) NULL,
  start_month character varying(7) NULL,
  end_month character varying(7) NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT hr_salary_components_pkey PRIMARY KEY (id),
  CONSTRAINT hr_salary_components_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr_employees (id),
  CONSTRAINT hr_salary_components_salary_id_fkey FOREIGN KEY (salary_id) REFERENCES hr_salary_wages (id),
  CONSTRAINT chk_hr_components_app_type CHECK (
    (application_type)::text = ANY (
      (ARRAY[
        'single'::character varying,
        'multiple'::character varying
      ])::text[]
    )
  ),
  CONSTRAINT chk_hr_components_type CHECK (
    (component_type)::text = ANY (
      (ARRAY[
        'ALLOWANCE'::character varying,
        'DEDUCTION'::character varying
      ])::text[]
    )
  )
) TABLESPACE pg_default;

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_hr_components_employee_id 
  ON public.hr_salary_components USING btree (employee_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_components_salary_id 
  ON public.hr_salary_components USING btree (salary_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_components_type 
  ON public.hr_salary_components USING btree (component_type) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_components_enabled 
  ON public.hr_salary_components USING btree (is_enabled) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_components_app_type 
  ON public.hr_salary_components USING btree (application_type) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_components_single_month 
  ON public.hr_salary_components USING btree (single_month) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_components_period 
  ON public.hr_salary_components USING btree (start_month, end_month) TABLESPACE pg_default;

-- Comments for documentation
COMMENT ON TABLE public.hr_salary_components IS 'Salary components (allowances/deductions) with flexible application periods';
COMMENT ON COLUMN public.hr_salary_components.id IS 'Primary key - UUID generated automatically';
COMMENT ON COLUMN public.hr_salary_components.salary_id IS 'Foreign key reference to hr_salary_wages table (required)';
COMMENT ON COLUMN public.hr_salary_components.employee_id IS 'Foreign key reference to hr_employees table (required)';
COMMENT ON COLUMN public.hr_salary_components.component_type IS 'Type of component: ALLOWANCE or DEDUCTION (required, constrained)';
COMMENT ON COLUMN public.hr_salary_components.component_name IS 'Name/description of the salary component (required)';
COMMENT ON COLUMN public.hr_salary_components.amount IS 'Monetary amount of the component (12,2 precision)';
COMMENT ON COLUMN public.hr_salary_components.is_enabled IS 'Whether this component is currently enabled/active';
COMMENT ON COLUMN public.hr_salary_components.application_type IS 'Application period type: single or multiple months (constrained)';
COMMENT ON COLUMN public.hr_salary_components.single_month IS 'Specific month for single application (YYYY-MM format)';
COMMENT ON COLUMN public.hr_salary_components.start_month IS 'Start month for multiple application period (YYYY-MM format)';
COMMENT ON COLUMN public.hr_salary_components.end_month IS 'End month for multiple application period (YYYY-MM format)';
COMMENT ON COLUMN public.hr_salary_components.created_at IS 'Timestamp when the record was created';