-- Table 3: HR Departments
-- Purpose: Manages human resources departments with bilingual support
-- Created: 2025-09-29

CREATE TABLE public.hr_departments (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  department_name_en character varying(100) NOT NULL,
  department_name_ar character varying(100) NOT NULL,
  is_active boolean NULL DEFAULT true,
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT hr_departments_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_hr_departments_name_en 
  ON public.hr_departments USING btree (department_name_en) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_departments_name_ar 
  ON public.hr_departments USING btree (department_name_ar) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_departments_active 
  ON public.hr_departments USING btree (is_active) TABLESPACE pg_default;

-- Comments for documentation
COMMENT ON TABLE public.hr_departments IS 'Human Resources departments with bilingual (English/Arabic) support';
COMMENT ON COLUMN public.hr_departments.id IS 'Primary key - UUID generated automatically';
COMMENT ON COLUMN public.hr_departments.department_name_en IS 'Department name in English (required)';
COMMENT ON COLUMN public.hr_departments.department_name_ar IS 'Department name in Arabic (required)';
COMMENT ON COLUMN public.hr_departments.is_active IS 'Whether the department is currently active/operational';
COMMENT ON COLUMN public.hr_departments.created_at IS 'Timestamp when the record was created';