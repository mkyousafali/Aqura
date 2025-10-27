-- Create task_assignments table
CREATE TABLE IF NOT EXISTS public.task_assignments (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL,
  assignment_type TEXT NOT NULL,
  assigned_to_user_id UUID,
  assigned_to_branch_id BIGINT,
  assigned_by UUID NOT NULL,
  assigned_by_name TEXT,
  assigned_at TIMESTAMPTZ DEFAULT now(),
  status TEXT DEFAULT 'assigned',
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  schedule_date DATE,
  schedule_time TIME,
  deadline_date DATE,
  deadline_time TIME,
  deadline_datetime TIMESTAMPTZ,
  is_reassignable BOOLEAN DEFAULT true,
  is_recurring BOOLEAN DEFAULT false,
  recurring_pattern JSONB,
  notes TEXT,
  priority_override TEXT,
  require_task_finished BOOLEAN DEFAULT true,
  require_photo_upload BOOLEAN DEFAULT false,
  require_erp_reference BOOLEAN DEFAULT false,
  reassigned_from UUID,
  reassignment_reason TEXT,
  reassigned_at TIMESTAMPTZ,
  PRIMARY KEY (id)
);

-- Indexes for task_assignments
CREATE INDEX IF NOT EXISTS idx_task_assignments_task_id ON public.task_assignments(task_id);
CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_to_user_id ON public.task_assignments(assigned_to_user_id);
CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_to_branch_id ON public.task_assignments(assigned_to_branch_id);

-- Enable Row Level Security
ALTER TABLE public.task_assignments ENABLE ROW LEVEL SECURITY;
