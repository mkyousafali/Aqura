-- Quick Task Assignments Table Schema
CREATE TABLE IF NOT EXISTS quick_task_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL,
  assigned_to UUID NOT NULL,
  assigned_by UUID,
  status VARCHAR NOT NULL DEFAULT 'pending',
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  due_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
