-- Migration for table: user_audit_logs
-- Generated on: 2025-10-30T21:55:45.316Z

CREATE TABLE IF NOT EXISTS public.user_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    user_id UUID NOT NULL,
    target_user_id JSONB,
    action VARCHAR(255) NOT NULL,
    table_name JSONB,
    record_id JSONB,
    old_values JSONB,
    new_values JSONB,
    ip_address JSONB,
    user_agent TEXT NOT NULL,
    performed_by JSONB,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_user_id ON public.user_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_created_at ON public.user_audit_logs(created_at);

-- Enable Row Level Security
ALTER TABLE public.user_audit_logs ENABLE ROW LEVEL SECURITY;

-- Table comments
COMMENT ON TABLE public.user_audit_logs IS 'Generated from Aqura schema analysis';
