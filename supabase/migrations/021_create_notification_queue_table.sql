-- Create notification_queue table
CREATE TABLE IF NOT EXISTS public.notification_queue (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  notification_id UUID NOT NULL,
  user_id UUID NOT NULL,
  device_id VARCHAR(255),
  push_subscription_id UUID,
  status VARCHAR(255) DEFAULT 'pending',
  payload JSONB NOT NULL,
  scheduled_at TIMESTAMPTZ DEFAULT now(),
  sent_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  error_message TEXT,
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  next_retry_at TIMESTAMPTZ,
  last_attempt_at TIMESTAMPTZ,
  PRIMARY KEY (id)
);

-- Indexes for notification_queue
CREATE INDEX IF NOT EXISTS idx_notification_queue_notification_id ON public.notification_queue(notification_id);
CREATE INDEX IF NOT EXISTS idx_notification_queue_user_id ON public.notification_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_queue_device_id ON public.notification_queue(device_id);
CREATE INDEX IF NOT EXISTS idx_notification_queue_push_subscription_id ON public.notification_queue(push_subscription_id);
CREATE INDEX IF NOT EXISTS idx_notification_queue_created_at ON public.notification_queue(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.notification_queue ENABLE ROW LEVEL SECURITY;
