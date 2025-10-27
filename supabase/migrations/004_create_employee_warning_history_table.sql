-- Create employee_warning_history table
CREATE TABLE IF NOT EXISTS public.employee_warning_history (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  warning_id UUID NOT NULL,
  action_type VARCHAR(255) NOT NULL,
  old_values JSONB,
  new_values JSONB,
  changed_by UUID,
  changed_by_username VARCHAR(255),
  change_reason TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  ip_address INET,
  user_agent TEXT,
  PRIMARY KEY (id)
);

-- Indexes for employee_warning_history
CREATE INDEX IF NOT EXISTS idx_employee_warning_history_warning_id ON public.employee_warning_history(warning_id);
CREATE INDEX IF NOT EXISTS idx_employee_warning_history_created_at ON public.employee_warning_history(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.employee_warning_history ENABLE ROW LEVEL SECURITY;
