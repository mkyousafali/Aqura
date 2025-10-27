-- Create hr_position_assignments table
CREATE TABLE IF NOT EXISTS public.hr_position_assignments (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL,
  position_id UUID NOT NULL,
  department_id UUID NOT NULL,
  level_id UUID NOT NULL,
  branch_id BIGINT NOT NULL,
  effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
  is_current BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for hr_position_assignments
CREATE INDEX IF NOT EXISTS idx_hr_position_assignments_employee_id ON public.hr_position_assignments(employee_id);
CREATE INDEX IF NOT EXISTS idx_hr_position_assignments_position_id ON public.hr_position_assignments(position_id);
CREATE INDEX IF NOT EXISTS idx_hr_position_assignments_department_id ON public.hr_position_assignments(department_id);
CREATE INDEX IF NOT EXISTS idx_hr_position_assignments_level_id ON public.hr_position_assignments(level_id);
CREATE INDEX IF NOT EXISTS idx_hr_position_assignments_branch_id ON public.hr_position_assignments(branch_id);
CREATE INDEX IF NOT EXISTS idx_hr_position_assignments_created_at ON public.hr_position_assignments(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.hr_position_assignments ENABLE ROW LEVEL SECURITY;
