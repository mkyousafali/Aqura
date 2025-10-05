-- HR Position Assignments Schema
-- This table stores employee position assignments with department, level, and branch relationships

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

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_hr_assignments_employee_id ON public.hr_position_assignments USING btree (employee_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_assignments_branch_id ON public.hr_position_assignments USING btree (branch_id) TABLESPACE pg_default;