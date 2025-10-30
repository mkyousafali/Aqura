-- Migration for table: user_password_history
-- Generated on: 2025-10-30T21:55:45.288Z

-- Note: Limited access to table schema
-- This is a basic table structure based on available information

CREATE TABLE IF NOT EXISTS public.user_password_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.user_password_history ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_user_password_history_updated_at
    BEFORE UPDATE ON public.user_password_history
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

