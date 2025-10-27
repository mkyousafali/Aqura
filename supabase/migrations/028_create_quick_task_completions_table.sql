-- Create quick_task_completions table
CREATE TABLE IF NOT EXISTS public.quick_task_completions (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  quick_task_id UUID NOT NULL,
  assignment_id UUID NOT NULL,
  completed_by_user_id UUID NOT NULL,
  completion_notes TEXT,
  photo_path TEXT,
  erp_reference VARCHAR(255),
  completion_status VARCHAR(255) NOT NULL DEFAULT 'submitted',
  verified_by_user_id UUID,
  verified_at TIMESTAMPTZ,
  verification_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for quick_task_completions
CREATE INDEX IF NOT EXISTS idx_quick_task_completions_quick_task_id ON public.quick_task_completions(quick_task_id);
CREATE INDEX IF NOT EXISTS idx_quick_task_completions_assignment_id ON public.quick_task_completions(assignment_id);
CREATE INDEX IF NOT EXISTS idx_quick_task_completions_completed_by_user_id ON public.quick_task_completions(completed_by_user_id);
CREATE INDEX IF NOT EXISTS idx_quick_task_completions_verified_by_user_id ON public.quick_task_completions(verified_by_user_id);
CREATE INDEX IF NOT EXISTS idx_quick_task_completions_created_at ON public.quick_task_completions(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.quick_task_completions ENABLE ROW LEVEL SECURITY;
