-- Table 6: HR Employees
-- Purpose: Core employee records with branch assignments and status tracking
-- Created: 2025-09-29

CREATE TABLE public.hr_employees (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  employee_id character varying(10) NOT NULL,
  branch_id bigint NOT NULL,
  hire_date date NULL,
  status character varying(20) NULL DEFAULT 'active'::character varying,
  created_at timestamp with time zone NULL DEFAULT now(),
  name character varying(200) NOT NULL,
  CONSTRAINT hr_employees_pkey PRIMARY KEY (id),
  CONSTRAINT hr_employees_employee_id_branch_id_unique UNIQUE (employee_id, branch_id),
  CONSTRAINT hr_employees_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches (id)
) TABLESPACE pg_default;

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_hr_employees_employee_id_branch_id 
  ON public.hr_employees USING btree (employee_id, branch_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_employees_employee_id 
  ON public.hr_employees USING btree (employee_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_employees_branch_id 
  ON public.hr_employees USING btree (branch_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_employees_status 
  ON public.hr_employees USING btree (status) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_employees_hire_date 
  ON public.hr_employees USING btree (hire_date) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_employees_name 
  ON public.hr_employees USING btree (name) TABLESPACE pg_default;

-- Comments for documentation
COMMENT ON TABLE public.hr_employees IS 'Core employee records with branch assignments and employment status';
COMMENT ON COLUMN public.hr_employees.id IS 'Primary key - UUID generated automatically';
COMMENT ON COLUMN public.hr_employees.employee_id IS 'Human-readable employee identifier (10 chars max)';
COMMENT ON COLUMN public.hr_employees.branch_id IS 'Foreign key reference to branches table (required)';
COMMENT ON COLUMN public.hr_employees.hire_date IS 'Date when employee was hired (optional)';
COMMENT ON COLUMN public.hr_employees.status IS 'Employment status (default: active)';
COMMENT ON COLUMN public.hr_employees.created_at IS 'Timestamp when the record was created';
COMMENT ON COLUMN public.hr_employees.name IS 'Full name of the employee (required)';