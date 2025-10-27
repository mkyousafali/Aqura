-- Create hr_salary_components table
CREATE TABLE IF NOT EXISTS public.hr_salary_components (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  salary_id UUID NOT NULL,
  employee_id UUID NOT NULL,
  component_type VARCHAR(255) NOT NULL,
  component_name VARCHAR(255) NOT NULL,
  amount NUMERIC NOT NULL,
  is_enabled BOOLEAN DEFAULT true,
  application_type VARCHAR(255),
  single_month VARCHAR(255),
  start_month VARCHAR(255),
  end_month VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for hr_salary_components
CREATE INDEX IF NOT EXISTS idx_hr_salary_components_salary_id ON public.hr_salary_components(salary_id);
CREATE INDEX IF NOT EXISTS idx_hr_salary_components_employee_id ON public.hr_salary_components(employee_id);
CREATE INDEX IF NOT EXISTS idx_hr_salary_components_created_at ON public.hr_salary_components(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.hr_salary_components ENABLE ROW LEVEL SECURITY;
