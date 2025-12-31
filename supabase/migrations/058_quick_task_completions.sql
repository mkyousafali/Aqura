-- Quick Task Completions Table Schema
CREATE TABLE IF NOT EXISTS quick_task_completions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL,
  completed_by UUID NOT NULL,
  completion_notes TEXT,
  completion_time TIMESTAMP WITH TIME ZONE,
  completion_proof JSONB,
  verified BOOLEAN NOT NULL DEFAULT false,
  verified_by UUID,
  verified_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
