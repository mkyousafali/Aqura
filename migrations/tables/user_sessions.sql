-- Migration for table: user_sessions
-- Generated on: 2025-10-30T21:55:45.326Z

CREATE TABLE IF NOT EXISTS public.user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    user_id UUID NOT NULL,
    session_token VARCHAR(255) NOT NULL,
    login_method VARCHAR(255) NOT NULL,
    ip_address JSONB,
    user_agent JSONB,
    is_active BOOLEAN DEFAULT true NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    ended_at JSONB
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON public.user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_created_at ON public.user_sessions(created_at);

-- Enable Row Level Security
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;

-- Table comments
COMMENT ON TABLE public.user_sessions IS 'Generated from Aqura schema analysis';
