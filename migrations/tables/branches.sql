-- Migration for table: branches
-- Generated on: 2025-10-30T21:55:45.308Z

CREATE TABLE IF NOT EXISTS public.branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    name_en VARCHAR(255) NOT NULL,
    name_ar VARCHAR(255) NOT NULL,
    location_en VARCHAR(255) NOT NULL,
    location_ar VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    is_main_branch BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    created_by JSONB,
    updated_by JSONB,
    vat_number VARCHAR(255) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_branches_created_at ON public.branches(created_at);
CREATE INDEX IF NOT EXISTS idx_branches_updated_at ON public.branches(updated_at);

-- Enable Row Level Security
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_branches_updated_at
    BEFORE UPDATE ON public.branches
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.branches IS 'Generated from Aqura schema analysis';
