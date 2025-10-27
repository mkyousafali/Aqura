-- Create quick_task_user_preferences table
CREATE TABLE IF NOT EXISTS public.quick_task_user_preferences (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  default_branch_id BIGINT,
  default_price_tag VARCHAR(255),
  default_issue_type VARCHAR(255),
  default_priority VARCHAR(255),
  selected_user_ids TEXT[],
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for quick_task_user_preferences
CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_user_id ON public.quick_task_user_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_default_branch_id ON public.quick_task_user_preferences(default_branch_id);
CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_created_at ON public.quick_task_user_preferences(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.quick_task_user_preferences ENABLE ROW LEVEL SECURITY;
