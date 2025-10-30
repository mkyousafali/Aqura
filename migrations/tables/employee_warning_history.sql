-- Migration for table: employee_warning_history
-- Generated on: 2025-10-30T21:55:45.317Z

CREATE TABLE IF NOT EXISTS public.employee_warning_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    warning_id UUID NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    old_values JSONB,
    new_values JSONB NOT NULL,
    changed_by UUID NOT NULL,
    changed_by_username VARCHAR(255) NOT NULL,
    change_reason VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    ip_address JSONB,
    user_agent JSONB
);

CREATE INDEX IF NOT EXISTS idx_employee_warning_history_action_type ON public.employee_warning_history(action_type);
CREATE INDEX IF NOT EXISTS idx_employee_warning_history_created_at ON public.employee_warning_history(created_at);

-- Enable Row Level Security
ALTER TABLE public.employee_warning_history ENABLE ROW LEVEL SECURITY;

-- Table comments
COMMENT ON TABLE public.employee_warning_history IS 'Generated from Aqura schema analysis';
