-- Migration for table: user_management_view
-- Generated on: 2025-10-30T21:55:45.313Z

CREATE TABLE IF NOT EXISTS public.user_management_view (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    username VARCHAR(255) NOT NULL,
    user_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,
    role_type VARCHAR(50) NOT NULL,
    is_first_login BOOLEAN DEFAULT true NOT NULL,
    last_login TIMESTAMPTZ NOT NULL,
    failed_login_attempts NUMERIC NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    avatar JSONB,
    employee_id UUID NOT NULL,
    employee_code VARCHAR(50) NOT NULL,
    employee_name VARCHAR(255) NOT NULL,
    employee_status VARCHAR(50) NOT NULL,
    hire_date JSONB,
    branch_id UUID NOT NULL,
    branch_name VARCHAR(255) NOT NULL,
    branch_name_ar VARCHAR(255) NOT NULL,
    branch_location_en VARCHAR(255) NOT NULL,
    branch_location_ar VARCHAR(255) NOT NULL,
    branch_active BOOLEAN DEFAULT true NOT NULL,
    position_id UUID NOT NULL,
    position_title_en VARCHAR(255) NOT NULL,
    position_title_ar VARCHAR(255) NOT NULL,
    department_id UUID NOT NULL,
    department_name_en VARCHAR(255) NOT NULL,
    department_name_ar VARCHAR(255) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_user_management_view_user_type ON public.user_management_view(user_type);
CREATE INDEX IF NOT EXISTS idx_user_management_view_status ON public.user_management_view(status);
CREATE INDEX IF NOT EXISTS idx_user_management_view_role_type ON public.user_management_view(role_type);
CREATE INDEX IF NOT EXISTS idx_user_management_view_created_at ON public.user_management_view(created_at);
CREATE INDEX IF NOT EXISTS idx_user_management_view_updated_at ON public.user_management_view(updated_at);
CREATE INDEX IF NOT EXISTS idx_user_management_view_employee_id ON public.user_management_view(employee_id);
CREATE INDEX IF NOT EXISTS idx_user_management_view_employee_status ON public.user_management_view(employee_status);
CREATE INDEX IF NOT EXISTS idx_user_management_view_branch_id ON public.user_management_view(branch_id);
CREATE INDEX IF NOT EXISTS idx_user_management_view_department_id ON public.user_management_view(department_id);

-- Enable Row Level Security
ALTER TABLE public.user_management_view ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_user_management_view_updated_at
    BEFORE UPDATE ON public.user_management_view
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.user_management_view IS 'Generated from Aqura schema analysis';
