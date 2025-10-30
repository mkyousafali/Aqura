-- Migration for table: task_images
-- Generated on: 2025-10-30T21:55:45.331Z

-- Note: Limited access to table schema
-- This is a basic table structure based on available information

CREATE TABLE IF NOT EXISTS public.task_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.task_images ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_task_images_updated_at
    BEFORE UPDATE ON public.task_images
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

