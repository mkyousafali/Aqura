-- Migration for table: position_roles_view
-- Generated on: 2025-10-30T21:55:45.310Z

CREATE TABLE IF NOT EXISTS public.position_roles_view (
    role_id UUID NOT NULL,
    role_name VARCHAR(255) NOT NULL,
    role_code VARCHAR(50) NOT NULL,
    role_description VARCHAR(255) NOT NULL,
    is_system_role BOOLEAN DEFAULT true NOT NULL,
    position_id JSONB,
    position_title_en JSONB,
    position_title_ar JSONB,
    department_id UUID,
    department_name_en JSONB,
    department_name_ar JSONB,
    level_id JSONB,
    level_name_en JSONB,
    level_name_ar JSONB,
    level_order JSONB
);

CREATE INDEX IF NOT EXISTS idx_position_roles_view_department_id ON public.position_roles_view(department_id);

-- Enable Row Level Security
ALTER TABLE public.position_roles_view ENABLE ROW LEVEL SECURITY;

-- Table comments
COMMENT ON TABLE public.position_roles_view IS 'Generated from Aqura schema analysis';
