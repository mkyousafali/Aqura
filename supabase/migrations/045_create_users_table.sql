-- Create users table
CREATE TABLE IF NOT EXISTS public.users (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  username VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  salt VARCHAR(255) NOT NULL,
  quick_access_code VARCHAR(255) NOT NULL,
  quick_access_salt VARCHAR(255) NOT NULL,
  user_type user_type_enum NOT NULL DEFAULT 'branch_specific',
  employee_id UUID,
  branch_id BIGINT,
  role_type role_type_enum DEFAULT 'Position-based',
  position_id UUID,
  avatar TEXT,
  avatar_small_url TEXT,
  avatar_medium_url TEXT,
  avatar_large_url TEXT,
  is_first_login BOOLEAN DEFAULT true,
  failed_login_attempts INTEGER DEFAULT 0,
  locked_at TIMESTAMPTZ,
  locked_by UUID,
  last_login_at TIMESTAMPTZ,
  password_expires_at TIMESTAMPTZ,
  last_password_change TIMESTAMPTZ DEFAULT now(),
  created_by BIGINT,
  updated_by BIGINT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  status VARCHAR(255) NOT NULL DEFAULT 'active',
  ai_translation_enabled BOOLEAN NOT NULL DEFAULT false,
  can_approve_payments BOOLEAN DEFAULT false,
  approval_amount_limit NUMERIC DEFAULT 0.00,
  PRIMARY KEY (id)
);

-- Indexes for users
CREATE INDEX IF NOT EXISTS idx_users_employee_id ON public.users(employee_id);
CREATE INDEX IF NOT EXISTS idx_users_branch_id ON public.users(branch_id);
CREATE INDEX IF NOT EXISTS idx_users_position_id ON public.users(position_id);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON public.users(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
