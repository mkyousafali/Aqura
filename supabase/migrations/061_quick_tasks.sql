-- Quick Tasks Table Schema
CREATE TABLE IF NOT EXISTS quick_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR NOT NULL,
  description TEXT,
  category VARCHAR NOT NULL,
  priority VARCHAR NOT NULL DEFAULT 'medium',
  status VARCHAR NOT NULL DEFAULT 'open',
  created_by UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  due_date TIMESTAMP WITH TIME ZONE,
  completion_target TIMESTAMP WITH TIME ZONE,
  branch_id UUID,
  tags TEXT[]
);
