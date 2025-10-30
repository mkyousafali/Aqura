-- Migration for table: task_completions
-- Generated on: 2025-10-30T21:55:45.315Z

CREATE TABLE IF NOT EXISTS public.task_completions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    task_id UUID NOT NULL,
    assignment_id UUID NOT NULL,
    completed_by UUID NOT NULL,
    completed_by_name VARCHAR(255) NOT NULL,
    completed_by_branch_id JSONB,
    task_finished_completed BOOLEAN DEFAULT true NOT NULL,
    photo_uploaded_completed JSONB,
    erp_reference_completed VARCHAR(100),
    erp_reference_number VARCHAR(100),
    completion_notes JSONB,
    verified_by JSONB,
    verified_at JSONB,
    verification_notes JSONB,
    completed_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    completion_photo_url TEXT
);

CREATE INDEX IF NOT EXISTS idx_task_completions_task_id ON public.task_completions(task_id);
CREATE INDEX IF NOT EXISTS idx_task_completions_assignment_id ON public.task_completions(assignment_id);
CREATE INDEX IF NOT EXISTS idx_task_completions_created_at ON public.task_completions(created_at);

-- Enable Row Level Security
ALTER TABLE public.task_completions ENABLE ROW LEVEL SECURITY;

-- Table comments
COMMENT ON TABLE public.task_completions IS 'Generated from Aqura schema analysis';
