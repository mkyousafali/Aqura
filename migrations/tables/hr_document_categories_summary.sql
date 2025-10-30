-- Migration for table: hr_document_categories_summary
-- Generated on: 2025-10-30T21:55:45.278Z

-- Note: Limited access to table schema
-- This is a basic table structure based on available information

CREATE TABLE IF NOT EXISTS public.hr_document_categories_summary (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.hr_document_categories_summary ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_hr_document_categories_summary_updated_at
    BEFORE UPDATE ON public.hr_document_categories_summary
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

