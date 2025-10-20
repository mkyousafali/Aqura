-- Migration: Create hr_departments table
-- File: 6_hr_departments.sql
-- Description: Creates the hr_departments table for managing HR departments with bilingual support

BEGIN;

-- Create hr_departments table
CREATE TABLE public.hr_departments (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  department_name_en character varying(100) NOT NULL,
  department_name_ar character varying(100) NOT NULL,
  is_active boolean NULL DEFAULT true,
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT hr_departments_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

COMMIT;