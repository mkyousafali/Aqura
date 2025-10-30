-- Migration for table: hr_position_assignments
-- Generated on: 2025-10-30T21:55:45.325Z

CREATE TABLE IF NOT EXISTS public.hr_position_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    employee_id UUID NOT NULL,
    position_id UUID NOT NULL,
    department_id UUID NOT NULL,
    level_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    effective_date DATE NOT NULL,
    is_current BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_hr_position_assignments_employee_id ON public.hr_position_assignments(employee_id);
CREATE INDEX IF NOT EXISTS idx_hr_position_assignments_department_id ON public.hr_position_assignments(department_id);
CREATE INDEX IF NOT EXISTS idx_hr_position_assignments_branch_id ON public.hr_position_assignments(branch_id);
CREATE INDEX IF NOT EXISTS idx_hr_position_assignments_created_at ON public.hr_position_assignments(created_at);

-- Enable Row Level Security
ALTER TABLE public.hr_position_assignments ENABLE ROW LEVEL SECURITY;

-- Table comments
COMMENT ON TABLE public.hr_position_assignments IS 'Generated from Aqura schema analysis';
