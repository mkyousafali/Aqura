-- Migration for table: tasks
-- Generated on: 2025-10-30T21:55:45.301Z

CREATE TABLE IF NOT EXISTS public.tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    require_task_finished BOOLEAN DEFAULT false NOT NULL,
    require_photo_upload BOOLEAN DEFAULT false NOT NULL,
    require_erp_reference VARCHAR(100) NOT NULL,
    can_escalate BOOLEAN DEFAULT false NOT NULL,
    can_reassign BOOLEAN DEFAULT false NOT NULL,
    created_by UUID NOT NULL,
    created_by_name VARCHAR(255) NOT NULL,
    created_by_role VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    priority VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ,
    due_date TIMESTAMPTZ,
    due_time JSONB,
    due_datetime TIMESTAMPTZ NOT NULL,
    search_vector TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON public.tasks(created_at);
CREATE INDEX IF NOT EXISTS idx_tasks_updated_at ON public.tasks(updated_at);
CREATE INDEX IF NOT EXISTS idx_tasks_deleted_at ON public.tasks(deleted_at);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON public.tasks(due_date);

-- Enable Row Level Security
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_tasks_updated_at
    BEFORE UPDATE ON public.tasks
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.tasks IS 'Generated from Aqura schema analysis';
