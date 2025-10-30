-- Migration for table: hr_positions
-- Generated on: 2025-10-30T21:55:45.314Z

CREATE TABLE IF NOT EXISTS public.hr_positions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    position_title_en VARCHAR(255) NOT NULL,
    position_title_ar VARCHAR(255) NOT NULL,
    department_id UUID NOT NULL,
    level_id UUID NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_hr_positions_department_id ON public.hr_positions(department_id);
CREATE INDEX IF NOT EXISTS idx_hr_positions_created_at ON public.hr_positions(created_at);

-- Enable Row Level Security
ALTER TABLE public.hr_positions ENABLE ROW LEVEL SECURITY;

-- Table comments
COMMENT ON TABLE public.hr_positions IS 'Generated from Aqura schema analysis';
