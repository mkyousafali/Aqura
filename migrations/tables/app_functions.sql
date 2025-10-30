-- Migration for table: app_functions
-- Generated on: 2025-10-30T21:55:45.299Z

CREATE TABLE IF NOT EXISTS public.app_functions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    function_name VARCHAR(255) NOT NULL,
    function_code VARCHAR(50) NOT NULL,
    description VARCHAR(255) NOT NULL,
    category VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_app_functions_created_at ON public.app_functions(created_at);
CREATE INDEX IF NOT EXISTS idx_app_functions_updated_at ON public.app_functions(updated_at);

-- Enable Row Level Security
ALTER TABLE public.app_functions ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_app_functions_updated_at
    BEFORE UPDATE ON public.app_functions
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.app_functions IS 'Generated from Aqura schema analysis';
