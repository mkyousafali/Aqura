-- Create quick_task_comments table
CREATE TABLE IF NOT EXISTS public.quick_task_comments (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  quick_task_id UUID NOT NULL,
  comment TEXT NOT NULL,
  comment_type VARCHAR(255) DEFAULT 'comment',
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for quick_task_comments
CREATE INDEX IF NOT EXISTS idx_quick_task_comments_quick_task_id ON public.quick_task_comments(quick_task_id);
CREATE INDEX IF NOT EXISTS idx_quick_task_comments_created_at ON public.quick_task_comments(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.quick_task_comments ENABLE ROW LEVEL SECURITY;
