-- Migration for table: hr_employees
-- Generated on: 2025-10-30T21:55:45.269Z

CREATE TABLE IF NOT EXISTS public.hr_employees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    employee_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    hire_date JSONB,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    name VARCHAR(255) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_hr_employees_employee_id ON public.hr_employees(employee_id);
CREATE INDEX IF NOT EXISTS idx_hr_employees_branch_id ON public.hr_employees(branch_id);
CREATE INDEX IF NOT EXISTS idx_hr_employees_status ON public.hr_employees(status);
CREATE INDEX IF NOT EXISTS idx_hr_employees_created_at ON public.hr_employees(created_at);

-- Enable Row Level Security
ALTER TABLE public.hr_employees ENABLE ROW LEVEL SECURITY;

-- Table comments
COMMENT ON TABLE public.hr_employees IS 'Generated from Aqura schema analysis';
