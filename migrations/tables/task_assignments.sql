-- Migration for table: task_assignments
-- Generated on: 2025-10-30T21:55:45.282Z

CREATE TABLE IF NOT EXISTS public.task_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    task_id UUID NOT NULL,
    assignment_type VARCHAR(50) NOT NULL,
    assigned_to_user_id UUID NOT NULL,
    assigned_to_branch_id JSONB,
    assigned_by UUID NOT NULL,
    assigned_by_name VARCHAR(255) NOT NULL,
    assigned_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(50) NOT NULL,
    started_at JSONB,
    completed_at TIMESTAMPTZ NOT NULL,
    schedule_date JSONB,
    schedule_time JSONB,
    deadline_date JSONB,
    deadline_time JSONB,
    deadline_datetime JSONB,
    is_reassignable BOOLEAN DEFAULT true NOT NULL,
    is_recurring BOOLEAN DEFAULT false NOT NULL,
    recurring_pattern JSONB,
    notes JSONB,
    priority_override JSONB,
    require_task_finished BOOLEAN DEFAULT false NOT NULL,
    require_photo_upload BOOLEAN DEFAULT false NOT NULL,
    require_erp_reference VARCHAR(100) NOT NULL,
    reassigned_from JSONB,
    reassignment_reason JSONB,
    reassigned_at JSONB
);

CREATE INDEX IF NOT EXISTS idx_task_assignments_task_id ON public.task_assignments(task_id);
CREATE INDEX IF NOT EXISTS idx_task_assignments_assignment_type ON public.task_assignments(assignment_type);
CREATE INDEX IF NOT EXISTS idx_task_assignments_status ON public.task_assignments(status);

-- Enable Row Level Security
ALTER TABLE public.task_assignments ENABLE ROW LEVEL SECURITY;

-- Table comments
COMMENT ON TABLE public.task_assignments IS 'Generated from Aqura schema analysis';
