-- Migration for table: user_roles
-- Generated on: 2025-10-30T21:55:45.320Z

CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    role_name VARCHAR(255) NOT NULL,
    role_code VARCHAR(50) NOT NULL,
    description VARCHAR(255) NOT NULL,
    is_system_role BOOLEAN DEFAULT false NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    created_by JSONB,
    updated_by JSONB
);

CREATE INDEX IF NOT EXISTS idx_user_roles_created_at ON public.user_roles(created_at);
CREATE INDEX IF NOT EXISTS idx_user_roles_updated_at ON public.user_roles(updated_at);

-- Enable Row Level Security
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_user_roles_updated_at
    BEFORE UPDATE ON public.user_roles
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.user_roles IS 'Generated from Aqura schema analysis';
