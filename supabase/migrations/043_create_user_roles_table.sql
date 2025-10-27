-- Create user_roles table
CREATE TABLE IF NOT EXISTS public.user_roles (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  role_name VARCHAR(255) NOT NULL,
  role_code VARCHAR(255) NOT NULL,
  description TEXT,
  is_system_role BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID,
  updated_by UUID,
  PRIMARY KEY (id)
);

-- Indexes for user_roles
CREATE INDEX IF NOT EXISTS idx_user_roles_created_at ON public.user_roles(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
