-- Migration: Create hr_salary_components table
-- File: 15_hr_salary_components.sql
-- Description: Creates the hr_salary_components table for managing employee salary allowances and deductions

BEGIN;

-- Create hr_salary_components table
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
    (
      (application_type)::text = ANY (
        (
          ARRAY[
            'single'::character varying,
            'multiple'::character varying
          ]
        )::text[]
      )
    )
  ),
  CONSTRAINT chk_hr_components_type CHECK (
    (
      (component_type)::text = ANY (
        (
          ARRAY[
            'ALLOWANCE'::character varying,
            'DEDUCTION'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_hr_components_employee_id 
ON public.hr_salary_components USING btree (employee_id) 
TABLESPACE pg_default;

COMMIT;