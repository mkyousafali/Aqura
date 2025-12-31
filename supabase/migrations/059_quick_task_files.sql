-- Quick Task Files Table Schema
CREATE TABLE IF NOT EXISTS quick_task_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL,
  file_name VARCHAR NOT NULL,
  file_url VARCHAR NOT NULL,
  file_type VARCHAR,
  file_size INTEGER,
  uploaded_by UUID,
  uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
