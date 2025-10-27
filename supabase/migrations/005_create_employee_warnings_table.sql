-- Create employee_warnings table
CREATE TABLE IF NOT EXISTS public.employee_warnings (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID,
  employee_id UUID,
  username VARCHAR(255),
  warning_type VARCHAR(255) NOT NULL,
  has_fine BOOLEAN DEFAULT false,
  fine_amount NUMERIC,
  fine_currency VARCHAR(255) DEFAULT 'USD',
  fine_status VARCHAR(255) DEFAULT 'pending',
  fine_due_date DATE,
  fine_paid_date TIMESTAMP,
  fine_paid_amount NUMERIC,
  warning_text TEXT NOT NULL,
  language_code VARCHAR(255) NOT NULL DEFAULT 'en',
  task_id UUID,
  task_title VARCHAR(255),
  task_description TEXT,
  assignment_id UUID,
  total_tasks_assigned INTEGER DEFAULT 0,
  total_tasks_completed INTEGER DEFAULT 0,
  total_tasks_overdue INTEGER DEFAULT 0,
  completion_rate NUMERIC DEFAULT 0,
  issued_by UUID,
  issued_by_username VARCHAR(255),
  issued_at TIMESTAMP DEFAULT now(),
  warning_status VARCHAR(255) DEFAULT 'active',
  acknowledged_at TIMESTAMP,
  acknowledged_by UUID,
  resolved_at TIMESTAMP,
  resolved_by UUID,
  resolution_notes TEXT,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  branch_id BIGINT,
  department_id UUID,
  severity_level VARCHAR(255) DEFAULT 'medium',
  follow_up_required BOOLEAN DEFAULT false,
  follow_up_date DATE,
  warning_reference VARCHAR(255),
  warning_document_url TEXT,
  is_deleted BOOLEAN DEFAULT false,
  deleted_at TIMESTAMP,
  deleted_by UUID,
  fine_paid_at TIMESTAMP,
  frontend_save_id VARCHAR(255),
  fine_payment_note TEXT,
  fine_payment_method VARCHAR(255) DEFAULT 'cash',
  fine_payment_reference VARCHAR(255),
  PRIMARY KEY (id)
);

-- Indexes for employee_warnings
CREATE INDEX IF NOT EXISTS idx_employee_warnings_user_id ON public.employee_warnings(user_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_employee_id ON public.employee_warnings(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_task_id ON public.employee_warnings(task_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_assignment_id ON public.employee_warnings(assignment_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_branch_id ON public.employee_warnings(branch_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_department_id ON public.employee_warnings(department_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_frontend_save_id ON public.employee_warnings(frontend_save_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_created_at ON public.employee_warnings(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.employee_warnings ENABLE ROW LEVEL SECURITY;
