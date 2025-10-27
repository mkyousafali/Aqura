-- Create quick_tasks table
CREATE TABLE IF NOT EXISTS public.quick_tasks (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  price_tag VARCHAR(255),
  issue_type VARCHAR(255) NOT NULL,
  priority VARCHAR(255) NOT NULL,
  assigned_by UUID NOT NULL,
  assigned_to_branch_id BIGINT,
  created_at TIMESTAMPTZ DEFAULT now(),
  deadline_datetime TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  status VARCHAR(255) DEFAULT 'pending',
  created_from VARCHAR(255) DEFAULT 'quick_task',
  updated_at TIMESTAMPTZ DEFAULT now(),
  require_task_finished BOOLEAN DEFAULT true,
  require_photo_upload BOOLEAN DEFAULT false,
  require_erp_reference BOOLEAN DEFAULT false,
  PRIMARY KEY (id)
);

-- Indexes for quick_tasks
CREATE INDEX IF NOT EXISTS idx_quick_tasks_assigned_to_branch_id ON public.quick_tasks(assigned_to_branch_id);
CREATE INDEX IF NOT EXISTS idx_quick_tasks_created_at ON public.quick_tasks(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.quick_tasks ENABLE ROW LEVEL SECURITY;
