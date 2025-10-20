-- Migration: Create hr_employees table
-- File: 9_hr_employees.sql
-- Description: Creates the hr_employees table for managing employee information

BEGIN;

-- Create hr_employees table
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

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_hr_employees_employee_id_branch_id 
ON public.hr_employees USING btree (employee_id, branch_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_employees_employee_id 
ON public.hr_employees USING btree (employee_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_employees_branch_id 
ON public.hr_employees USING btree (branch_id) 
TABLESPACE pg_default;

COMMIT;