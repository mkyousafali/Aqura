-- Create task_completions table
CREATE TABLE IF NOT EXISTS public.task_completions (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL,
  assignment_id UUID NOT NULL,
  completed_by TEXT NOT NULL,
  completed_by_name TEXT,
  completed_by_branch_id UUID,
  task_finished_completed BOOLEAN DEFAULT false,
  photo_uploaded_completed BOOLEAN DEFAULT false,
  erp_reference_completed BOOLEAN DEFAULT false,
  erp_reference_number TEXT,
  completion_notes TEXT,
  verified_by TEXT,
  verified_at TIMESTAMPTZ,
  verification_notes TEXT,
  completed_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  completion_photo_url TEXT,
  PRIMARY KEY (id)
);

-- Indexes for task_completions
CREATE INDEX IF NOT EXISTS idx_task_completions_task_id ON public.task_completions(task_id);
CREATE INDEX IF NOT EXISTS idx_task_completions_assignment_id ON public.task_completions(assignment_id);
CREATE INDEX IF NOT EXISTS idx_task_completions_completed_by_branch_id ON public.task_completions(completed_by_branch_id);
CREATE INDEX IF NOT EXISTS idx_task_completions_created_at ON public.task_completions(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.task_completions ENABLE ROW LEVEL SECURITY;
