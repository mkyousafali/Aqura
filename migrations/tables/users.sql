-- Migration for table: users
-- Generated on: 2025-10-30T21:55:45.325Z

CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    username VARCHAR(255) NOT NULL,
    password_hash TEXT NOT NULL,
    salt VARCHAR(255) NOT NULL,
    quick_access_code VARCHAR(50) NOT NULL,
    quick_access_salt TEXT NOT NULL,
    user_type VARCHAR(50) NOT NULL,
    employee_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    role_type VARCHAR(50) NOT NULL,
    position_id UUID NOT NULL,
    avatar JSONB,
    avatar_small_url TEXT,
    avatar_medium_url TEXT,
    avatar_large_url TEXT,
    is_first_login BOOLEAN DEFAULT true NOT NULL,
    failed_login_attempts NUMERIC NOT NULL,
    locked_at JSONB,
    locked_by JSONB,
    last_login_at TIMESTAMPTZ NOT NULL,
    password_expires_at TIMESTAMPTZ NOT NULL,
    last_password_change TIMESTAMPTZ NOT NULL,
    created_by JSONB,
    updated_by JSONB,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    status VARCHAR(50) NOT NULL,
    ai_translation_enabled BOOLEAN DEFAULT false NOT NULL,
    can_approve_payments BOOLEAN DEFAULT false NOT NULL,
    approval_amount_limit DECIMAL(12,2) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_users_user_type ON public.users(user_type);
CREATE INDEX IF NOT EXISTS idx_users_employee_id ON public.users(employee_id);
CREATE INDEX IF NOT EXISTS idx_users_branch_id ON public.users(branch_id);
CREATE INDEX IF NOT EXISTS idx_users_role_type ON public.users(role_type);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON public.users(created_at);
CREATE INDEX IF NOT EXISTS idx_users_updated_at ON public.users(updated_at);
CREATE INDEX IF NOT EXISTS idx_users_status ON public.users(status);

-- Enable Row Level Security
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.users IS 'Generated from Aqura schema analysis';
