-- Migration for table: hr_levels
-- Generated on: 2025-10-30T21:55:45.334Z

CREATE TABLE IF NOT EXISTS public.hr_levels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    level_name_en VARCHAR(255) NOT NULL,
    level_name_ar VARCHAR(255) NOT NULL,
    level_order NUMERIC NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_hr_levels_created_at ON public.hr_levels(created_at);

-- Enable Row Level Security
ALTER TABLE public.hr_levels ENABLE ROW LEVEL SECURITY;

-- Table comments
COMMENT ON TABLE public.hr_levels IS 'Generated from Aqura schema analysis';
