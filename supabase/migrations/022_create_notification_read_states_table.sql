-- Create notification_read_states table
CREATE TABLE IF NOT EXISTS public.notification_read_states (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  notification_id UUID NOT NULL,
  user_id TEXT NOT NULL,
  read_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  is_read BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (id)
);

-- Indexes for notification_read_states
CREATE INDEX IF NOT EXISTS idx_notification_read_states_notification_id ON public.notification_read_states(notification_id);
CREATE INDEX IF NOT EXISTS idx_notification_read_states_user_id ON public.notification_read_states(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_read_states_created_at ON public.notification_read_states(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.notification_read_states ENABLE ROW LEVEL SECURITY;
