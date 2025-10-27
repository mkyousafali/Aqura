-- Create notification_recipients table
CREATE TABLE IF NOT EXISTS public.notification_recipients (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  notification_id UUID NOT NULL,
  role VARCHAR(255),
  branch_id VARCHAR(255),
  is_read BOOLEAN NOT NULL DEFAULT false,
  read_at TIMESTAMPTZ,
  is_dismissed BOOLEAN NOT NULL DEFAULT false,
  dismissed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  delivery_status VARCHAR(255) DEFAULT 'pending',
  delivery_attempted_at TIMESTAMPTZ,
  error_message TEXT,
  user_id UUID,
  PRIMARY KEY (id)
);

-- Indexes for notification_recipients
CREATE INDEX IF NOT EXISTS idx_notification_recipients_notification_id ON public.notification_recipients(notification_id);
CREATE INDEX IF NOT EXISTS idx_notification_recipients_branch_id ON public.notification_recipients(branch_id);
CREATE INDEX IF NOT EXISTS idx_notification_recipients_user_id ON public.notification_recipients(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_recipients_created_at ON public.notification_recipients(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.notification_recipients ENABLE ROW LEVEL SECURITY;
