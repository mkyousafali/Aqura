-- Create role_permissions table
CREATE TABLE IF NOT EXISTS public.role_permissions (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  role_id UUID NOT NULL,
  function_id UUID NOT NULL,
  can_view BOOLEAN DEFAULT false,
  can_add BOOLEAN DEFAULT false,
  can_edit BOOLEAN DEFAULT false,
  can_delete BOOLEAN DEFAULT false,
  can_export BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for role_permissions
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id ON public.role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_function_id ON public.role_permissions(function_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_created_at ON public.role_permissions(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
