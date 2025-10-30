-- Migration for table: expense_requisitions
-- Generated on: 2025-10-30T21:55:45.309Z

-- Note: Limited access to table schema
-- This is a basic table structure based on available information

CREATE TABLE IF NOT EXISTS public.expense_requisitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.expense_requisitions ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_expense_requisitions_updated_at
    BEFORE UPDATE ON public.expense_requisitions
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

