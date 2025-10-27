-- Create quick_task_files table
CREATE TABLE IF NOT EXISTS public.quick_task_files (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  quick_task_id UUID NOT NULL,
  file_name VARCHAR(255) NOT NULL,
  file_type VARCHAR(255),
  file_size INTEGER,
  mime_type VARCHAR(255),
  storage_path TEXT NOT NULL,
  storage_bucket VARCHAR(255) DEFAULT 'quick-task-files',
  uploaded_by UUID,
  uploaded_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for quick_task_files
CREATE INDEX IF NOT EXISTS idx_quick_task_files_quick_task_id ON public.quick_task_files(quick_task_id);

-- Enable Row Level Security
ALTER TABLE public.quick_task_files ENABLE ROW LEVEL SECURITY;
