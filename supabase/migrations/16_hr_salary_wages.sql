-- Migration: Create hr_salary_wages table
-- File: 16_hr_salary_wages.sql
-- Description: Creates the hr_salary_wages table for managing employee basic salary information

BEGIN;

-- Create hr_salary_wages table
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

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_hr_salary_employee_id 
ON public.hr_salary_wages USING btree (employee_id) 
TABLESPACE pg_default;

COMMIT;