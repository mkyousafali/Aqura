-- Migration for table: hr_position_reporting_template
-- Generated on: 2025-10-30T21:55:45.331Z

CREATE TABLE IF NOT EXISTS public.hr_position_reporting_template (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    subordinate_position_id UUID NOT NULL,
    manager_position_1 JSONB,
    manager_position_2 JSONB,
    manager_position_3 JSONB,
    manager_position_4 JSONB,
    manager_position_5 JSONB,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_hr_position_reporting_template_created_at ON public.hr_position_reporting_template(created_at);

-- Enable Row Level Security
ALTER TABLE public.hr_position_reporting_template ENABLE ROW LEVEL SECURITY;

-- Table comments
COMMENT ON TABLE public.hr_position_reporting_template IS 'Generated from Aqura schema analysis';
