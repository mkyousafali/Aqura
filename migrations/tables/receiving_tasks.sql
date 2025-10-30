-- Migration for table: receiving_tasks
-- Generated on: 2025-10-30T21:55:45.329Z

-- Note: Limited access to table schema
-- This is a basic table structure based on available information

CREATE TABLE IF NOT EXISTS public.receiving_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.receiving_tasks ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_receiving_tasks_updated_at
    BEFORE UPDATE ON public.receiving_tasks
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

