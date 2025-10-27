-- Create hr_salary_wages table
CREATE TABLE IF NOT EXISTS public.hr_salary_wages (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL,
  branch_id UUID NOT NULL,
  basic_salary NUMERIC NOT NULL,
  effective_from DATE NOT NULL,
  is_current BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for hr_salary_wages
CREATE INDEX IF NOT EXISTS idx_hr_salary_wages_employee_id ON public.hr_salary_wages(employee_id);
CREATE INDEX IF NOT EXISTS idx_hr_salary_wages_branch_id ON public.hr_salary_wages(branch_id);
CREATE INDEX IF NOT EXISTS idx_hr_salary_wages_created_at ON public.hr_salary_wages(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.hr_salary_wages ENABLE ROW LEVEL SECURITY;
