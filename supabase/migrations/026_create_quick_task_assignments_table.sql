-- Create quick_task_assignments table
CREATE TABLE IF NOT EXISTS public.quick_task_assignments (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  quick_task_id UUID NOT NULL,
  assigned_to_user_id UUID NOT NULL,
  status VARCHAR(255) DEFAULT 'pending',
  accepted_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  require_task_finished BOOLEAN DEFAULT true,
  require_photo_upload BOOLEAN DEFAULT false,
  require_erp_reference BOOLEAN DEFAULT false,
  PRIMARY KEY (id)
);

-- Indexes for quick_task_assignments
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_quick_task_id ON public.quick_task_assignments(quick_task_id);
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_assigned_to_user_id ON public.quick_task_assignments(assigned_to_user_id);
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_created_at ON public.quick_task_assignments(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.quick_task_assignments ENABLE ROW LEVEL SECURITY;
