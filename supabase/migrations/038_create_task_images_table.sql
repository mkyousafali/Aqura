-- Create task_images table
CREATE TABLE IF NOT EXISTS public.task_images (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL,
  file_name TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  file_type TEXT NOT NULL,
  file_url TEXT NOT NULL,
  image_type TEXT NOT NULL,
  uploaded_by TEXT NOT NULL,
  uploaded_by_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  image_width INTEGER,
  image_height INTEGER,
  file_path TEXT,
  attachment_type TEXT DEFAULT 'task_creation',
  PRIMARY KEY (id)
);

-- Indexes for task_images
CREATE INDEX IF NOT EXISTS idx_task_images_task_id ON public.task_images(task_id);
CREATE INDEX IF NOT EXISTS idx_task_images_created_at ON public.task_images(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.task_images ENABLE ROW LEVEL SECURITY;
