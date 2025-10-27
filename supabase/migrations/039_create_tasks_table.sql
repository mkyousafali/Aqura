-- Create tasks table
CREATE TABLE IF NOT EXISTS public.tasks (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  require_task_finished BOOLEAN DEFAULT false,
  require_photo_upload BOOLEAN DEFAULT false,
  require_erp_reference BOOLEAN DEFAULT false,
  can_escalate BOOLEAN DEFAULT false,
  can_reassign BOOLEAN DEFAULT false,
  created_by TEXT NOT NULL,
  created_by_name TEXT,
  created_by_role TEXT,
  status TEXT DEFAULT 'draft',
  priority TEXT DEFAULT 'medium',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  due_date DATE,
  due_time TIME,
  due_datetime TIMESTAMPTZ,
  search_vector TSVECTOR,
  PRIMARY KEY (id)
);

-- Indexes for tasks
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON public.tasks(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
