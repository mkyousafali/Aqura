-- Table 9: HR Position Assignments
-- Purpose: Manages employee position assignments within organizational structure
-- Created: 2025-09-29

CREATE TABLE public.hr_position_assignments (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  employee_id uuid NOT NULL,
  position_id uuid NOT NULL,
  department_id uuid NOT NULL,
  level_id uuid NOT NULL,
  branch_id bigint NOT NULL,
  effective_date date NOT NULL DEFAULT CURRENT_DATE,
  is_current boolean NULL DEFAULT true,
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT hr_position_assignments_pkey PRIMARY KEY (id),
  CONSTRAINT hr_position_assignments_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches (id),
  CONSTRAINT hr_position_assignments_department_id_fkey FOREIGN KEY (department_id) REFERENCES hr_departments (id),
  CONSTRAINT hr_position_assignments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr_employees (id),
  CONSTRAINT hr_position_assignments_level_id_fkey FOREIGN KEY (level_id) REFERENCES hr_levels (id),
  CONSTRAINT hr_position_assignments_position_id_fkey FOREIGN KEY (position_id) REFERENCES hr_positions (id)
) TABLESPACE pg_default;

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_hr_assignments_employee_id 
  ON public.hr_position_assignments USING btree (employee_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_assignments_branch_id 
  ON public.hr_position_assignments USING btree (branch_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_assignments_position_id 
  ON public.hr_position_assignments USING btree (position_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_assignments_department_id 
  ON public.hr_position_assignments USING btree (department_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_assignments_level_id 
  ON public.hr_position_assignments USING btree (level_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_assignments_effective_date 
  ON public.hr_position_assignments USING btree (effective_date) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_assignments_current 
  ON public.hr_position_assignments USING btree (is_current) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_assignments_employee_current 
  ON public.hr_position_assignments USING btree (employee_id, is_current) TABLESPACE pg_default;

-- Unique constraint to ensure only one current assignment per employee
CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_assignments_employee_current_unique 
  ON public.hr_position_assignments USING btree (employee_id) WHERE is_current = true;

-- Comments for documentation
COMMENT ON TABLE public.hr_position_assignments IS 'Employee position assignments linking employees to their organizational roles';
COMMENT ON COLUMN public.hr_position_assignments.id IS 'Primary key - UUID generated automatically';
COMMENT ON COLUMN public.hr_position_assignments.employee_id IS 'Foreign key reference to hr_employees table (required)';
COMMENT ON COLUMN public.hr_position_assignments.position_id IS 'Foreign key reference to hr_positions table (required)';
COMMENT ON COLUMN public.hr_position_assignments.department_id IS 'Foreign key reference to hr_departments table (required)';
COMMENT ON COLUMN public.hr_position_assignments.level_id IS 'Foreign key reference to hr_levels table (required)';
COMMENT ON COLUMN public.hr_position_assignments.branch_id IS 'Foreign key reference to branches table (required)';
COMMENT ON COLUMN public.hr_position_assignments.effective_date IS 'Date when this assignment becomes effective (auto-set to current date)';
COMMENT ON COLUMN public.hr_position_assignments.is_current IS 'Whether this is the current active assignment for the employee';
COMMENT ON COLUMN public.hr_position_assignments.created_at IS 'Timestamp when the record was created';