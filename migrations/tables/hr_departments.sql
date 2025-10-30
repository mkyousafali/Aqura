-- Migration for table: hr_departments
-- Generated on: 2025-10-30T21:55:45.281Z

CREATE TABLE IF NOT EXISTS public.hr_departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    department_name_en VARCHAR(255) NOT NULL,
    department_name_ar VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_hr_departments_created_at ON public.hr_departments(created_at);

-- Enable Row Level Security
ALTER TABLE public.hr_departments ENABLE ROW LEVEL SECURITY;

-- Table comments
COMMENT ON TABLE public.hr_departments IS 'Generated from Aqura schema analysis';
