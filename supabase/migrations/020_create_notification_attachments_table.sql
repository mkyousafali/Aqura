-- Create notification_attachments table
CREATE TABLE IF NOT EXISTS public.notification_attachments (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  notification_id UUID NOT NULL,
  file_name VARCHAR(255) NOT NULL,
  file_path TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  file_type VARCHAR(255) NOT NULL,
  uploaded_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for notification_attachments
CREATE INDEX IF NOT EXISTS idx_notification_attachments_notification_id ON public.notification_attachments(notification_id);
CREATE INDEX IF NOT EXISTS idx_notification_attachments_created_at ON public.notification_attachments(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.notification_attachments ENABLE ROW LEVEL SECURITY;
