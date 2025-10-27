-- Create user_device_sessions table
CREATE TABLE IF NOT EXISTS public.user_device_sessions (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  device_id VARCHAR(255) NOT NULL,
  session_token VARCHAR(255) NOT NULL,
  device_type VARCHAR(255) NOT NULL,
  browser_name VARCHAR(255),
  user_agent TEXT,
  ip_address INET,
  is_active BOOLEAN DEFAULT true,
  login_at TIMESTAMPTZ DEFAULT now(),
  last_activity TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for user_device_sessions
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_user_id ON public.user_device_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_device_id ON public.user_device_sessions(device_id);
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_created_at ON public.user_device_sessions(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.user_device_sessions ENABLE ROW LEVEL SECURITY;
