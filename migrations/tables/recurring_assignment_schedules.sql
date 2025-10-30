-- Migration for table: recurring_assignment_schedules
-- Generated on: 2025-10-30T21:55:45.290Z

-- Note: Limited access to table schema
-- This is a basic table structure based on available information

CREATE TABLE IF NOT EXISTS public.recurring_assignment_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.recurring_assignment_schedules ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_recurring_assignment_schedules_updated_at
    BEFORE UPDATE ON public.recurring_assignment_schedules
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

