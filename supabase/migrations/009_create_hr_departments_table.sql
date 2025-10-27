-- Create hr_departments table
CREATE TABLE IF NOT EXISTS public.hr_departments (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  department_name_en VARCHAR(255) NOT NULL,
  department_name_ar VARCHAR(255) NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for hr_departments
CREATE INDEX IF NOT EXISTS idx_hr_departments_created_at ON public.hr_departments(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.hr_departments ENABLE ROW LEVEL SECURITY;
