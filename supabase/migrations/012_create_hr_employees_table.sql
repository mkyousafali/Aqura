-- Create hr_employees table
CREATE TABLE IF NOT EXISTS public.hr_employees (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  employee_id VARCHAR(255) NOT NULL,
  branch_id BIGINT NOT NULL,
  hire_date DATE,
  status VARCHAR(255) DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT now(),
  name VARCHAR(255) NOT NULL,
  PRIMARY KEY (id)
);

-- Indexes for hr_employees
CREATE INDEX IF NOT EXISTS idx_hr_employees_employee_id ON public.hr_employees(employee_id);
CREATE INDEX IF NOT EXISTS idx_hr_employees_branch_id ON public.hr_employees(branch_id);
CREATE INDEX IF NOT EXISTS idx_hr_employees_created_at ON public.hr_employees(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.hr_employees ENABLE ROW LEVEL SECURITY;
