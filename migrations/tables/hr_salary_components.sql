-- Migration for table: hr_salary_components
-- Generated on: 2025-10-30T21:55:45.279Z

-- Note: Limited access to table schema
-- This is a basic table structure based on available information

CREATE TABLE IF NOT EXISTS public.hr_salary_components (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.hr_salary_components ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_hr_salary_components_updated_at
    BEFORE UPDATE ON public.hr_salary_components
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

