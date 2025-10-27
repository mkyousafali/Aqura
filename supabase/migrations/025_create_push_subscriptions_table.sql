-- Create push_subscriptions table
CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  device_id VARCHAR(255) NOT NULL,
  endpoint TEXT NOT NULL,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  device_type VARCHAR(255) NOT NULL,
  browser_name VARCHAR(255),
  user_agent TEXT,
  is_active BOOLEAN DEFAULT true,
  last_seen TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  session_id TEXT,
  PRIMARY KEY (id)
);

-- Indexes for push_subscriptions
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON public.push_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_device_id ON public.push_subscriptions(device_id);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_session_id ON public.push_subscriptions(session_id);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_created_at ON public.push_subscriptions(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
