-- Migration for table: task_completion_summary
-- Generated on: 2025-10-30T21:55:45.300Z

CREATE TABLE IF NOT EXISTS public.task_completion_summary (
    completion_id UUID NOT NULL,
    task_id UUID NOT NULL,
    task_title VARCHAR(255) NOT NULL,
    task_priority VARCHAR(255) NOT NULL,
    assignment_id UUID NOT NULL,
    completed_by UUID NOT NULL,
    completed_by_name VARCHAR(255) NOT NULL,
    completed_by_branch_id JSONB,
    branch_name JSONB,
    task_finished_completed BOOLEAN DEFAULT true NOT NULL,
    photo_uploaded_completed JSONB,
    completion_photo_url TEXT,
    erp_reference_completed VARCHAR(100),
    erp_reference_number VARCHAR(100),
    completion_notes JSONB,
    verified_by JSONB,
    verified_at JSONB,
    verification_notes JSONB,
    completed_at TIMESTAMPTZ NOT NULL,
    completion_percentage DECIMAL(5,2) NOT NULL,
    is_fully_completed JSONB
);

CREATE INDEX IF NOT EXISTS idx_task_completion_summary_task_id ON public.task_completion_summary(task_id);
CREATE INDEX IF NOT EXISTS idx_task_completion_summary_assignment_id ON public.task_completion_summary(assignment_id);

-- Enable Row Level Security
ALTER TABLE public.task_completion_summary ENABLE ROW LEVEL SECURITY;

-- Table comments
COMMENT ON TABLE public.task_completion_summary IS 'Generated from Aqura schema analysis';
