-- Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  created_by VARCHAR(255) NOT NULL DEFAULT 'system',
  created_by_name VARCHAR(255) NOT NULL DEFAULT 'System',
  created_by_role VARCHAR(255) NOT NULL DEFAULT 'Admin',
  target_users JSONB,
  target_roles JSONB,
  target_branches JSONB,
  scheduled_for TIMESTAMPTZ,
  sent_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  has_attachments BOOLEAN NOT NULL DEFAULT false,
  read_count INTEGER NOT NULL DEFAULT 0,
  total_recipients INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  metadata JSONB,
  task_id UUID,
  task_assignment_id UUID,
  priority VARCHAR(255) NOT NULL DEFAULT 'medium',
  status VARCHAR(255) NOT NULL DEFAULT 'published',
  target_type VARCHAR(255) NOT NULL DEFAULT 'all_users',
  type VARCHAR(255) NOT NULL DEFAULT 'info',
  PRIMARY KEY (id)
);

-- Indexes for notifications
CREATE INDEX IF NOT EXISTS idx_notifications_task_id ON public.notifications(task_id);
CREATE INDEX IF NOT EXISTS idx_notifications_task_assignment_id ON public.notifications(task_assignment_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
