-- Create user_password_history table
CREATE TABLE IF NOT EXISTS public.user_password_history (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  salt VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for user_password_history
CREATE INDEX IF NOT EXISTS idx_user_password_history_user_id ON public.user_password_history(user_id);
CREATE INDEX IF NOT EXISTS idx_user_password_history_created_at ON public.user_password_history(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.user_password_history ENABLE ROW LEVEL SECURITY;
