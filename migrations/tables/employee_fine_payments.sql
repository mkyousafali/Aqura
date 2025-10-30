-- Migration for table: employee_fine_payments
-- Generated on: 2025-10-30T21:55:45.288Z

-- Note: Limited access to table schema
-- This is a basic table structure based on available information

CREATE TABLE IF NOT EXISTS public.employee_fine_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.employee_fine_payments ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_employee_fine_payments_updated_at
    BEFORE UPDATE ON public.employee_fine_payments
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

