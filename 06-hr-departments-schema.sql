-- HR Departments Schema
-- Manages company departments with bilingual support

CREATE TABLE public.hr_departments (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  department_name_en character varying(100) NOT NULL,
  department_name_ar character varying(100) NOT NULL,
  is_active boolean NULL DEFAULT true,
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT hr_departments_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;