-- Migration for table: hr_fingerprint_transactions
-- Generated on: 2025-10-30T21:55:45.307Z

-- Note: Limited access to table schema
-- This is a basic table structure based on available information

CREATE TABLE IF NOT EXISTS public.hr_fingerprint_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.hr_fingerprint_transactions ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_hr_fingerprint_transactions_updated_at
    BEFORE UPDATE ON public.hr_fingerprint_transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

