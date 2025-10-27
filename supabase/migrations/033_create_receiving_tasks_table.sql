-- Create receiving_tasks table
CREATE TABLE IF NOT EXISTS public.receiving_tasks (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  receiving_record_id UUID NOT NULL,
  task_id UUID NOT NULL,
  assignment_id UUID NOT NULL,
  role_type VARCHAR(255) NOT NULL,
  assigned_user_id UUID,
  requires_erp_reference BOOLEAN DEFAULT false,
  requires_original_bill_upload BOOLEAN DEFAULT false,
  requires_reassignment BOOLEAN DEFAULT false,
  requires_task_finished_mark BOOLEAN DEFAULT true,
  erp_reference_number VARCHAR(255),
  original_bill_uploaded BOOLEAN DEFAULT false,
  original_bill_file_path TEXT,
  task_completed BOOLEAN DEFAULT false,
  completed_at TIMESTAMPTZ,
  clearance_certificate_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for receiving_tasks
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_receiving_record_id ON public.receiving_tasks(receiving_record_id);
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_task_id ON public.receiving_tasks(task_id);
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_assignment_id ON public.receiving_tasks(assignment_id);
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_assigned_user_id ON public.receiving_tasks(assigned_user_id);
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_created_at ON public.receiving_tasks(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.receiving_tasks ENABLE ROW LEVEL SECURITY;
