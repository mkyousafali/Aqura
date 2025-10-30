-- Migration for table: role_permissions
-- Generated on: 2025-10-30T21:55:45.287Z

CREATE TABLE IF NOT EXISTS public.role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    role_id UUID NOT NULL,
    function_id UUID NOT NULL,
    can_view BOOLEAN DEFAULT true NOT NULL,
    can_add BOOLEAN DEFAULT true NOT NULL,
    can_edit BOOLEAN DEFAULT true NOT NULL,
    can_delete BOOLEAN DEFAULT true NOT NULL,
    can_export BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_role_permissions_created_at ON public.role_permissions(created_at);
CREATE INDEX IF NOT EXISTS idx_role_permissions_updated_at ON public.role_permissions(updated_at);

-- Enable Row Level Security
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_role_permissions_updated_at
    BEFORE UPDATE ON public.role_permissions
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.role_permissions IS 'Generated from Aqura schema analysis';
