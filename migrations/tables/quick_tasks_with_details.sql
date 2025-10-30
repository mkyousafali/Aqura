-- Migration for table: quick_tasks_with_details
-- Generated on: 2025-10-30T21:55:45.320Z

-- Note: Limited access to table schema
-- This is a basic table structure based on available information

CREATE TABLE IF NOT EXISTS public.quick_tasks_with_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.quick_tasks_with_details ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_quick_tasks_with_details_updated_at
    BEFORE UPDATE ON public.quick_tasks_with_details
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

