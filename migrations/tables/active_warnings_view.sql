-- Migration for table: active_warnings_view
-- Generated on: 2025-10-30T21:55:45.302Z

CREATE TABLE IF NOT EXISTS public.active_warnings_view (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    user_id UUID NOT NULL,
    employee_id UUID NOT NULL,
    username VARCHAR(255) NOT NULL,
    warning_type VARCHAR(50) NOT NULL,
    has_fine BOOLEAN DEFAULT false NOT NULL,
    fine_amount DECIMAL(12,2),
    fine_currency VARCHAR(3) NOT NULL,
    fine_status VARCHAR(50),
    fine_due_date JSONB,
    fine_paid_date JSONB,
    fine_paid_amount DECIMAL(12,2),
    warning_text TEXT NOT NULL,
    language_code VARCHAR(50) NOT NULL,
    task_id UUID,
    task_title VARCHAR(255) NOT NULL,
    task_description TEXT NOT NULL,
    assignment_id UUID NOT NULL,
    total_tasks_assigned NUMERIC NOT NULL,
    total_tasks_completed NUMERIC NOT NULL,
    total_tasks_overdue NUMERIC NOT NULL,
    completion_rate DECIMAL(12,2) NOT NULL,
    issued_by UUID NOT NULL,
    issued_by_username VARCHAR(255) NOT NULL,
    issued_at TIMESTAMPTZ NOT NULL,
    warning_status VARCHAR(50) NOT NULL,
    acknowledged_at TIMESTAMPTZ,
    acknowledged_by UUID,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID,
    resolution_notes JSONB,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    branch_id UUID,
    department_id UUID,
    severity_level VARCHAR(255) NOT NULL,
    follow_up_required BOOLEAN DEFAULT true NOT NULL,
    follow_up_date TIMESTAMPTZ,
    warning_reference VARCHAR(100) NOT NULL,
    warning_document_url TEXT NOT NULL,
    is_deleted BOOLEAN DEFAULT false NOT NULL,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    employee_name VARCHAR(255) NOT NULL,
    employee_code VARCHAR(50) NOT NULL,
    issued_by_user VARCHAR(255) NOT NULL,
    branch_name JSONB
);

CREATE INDEX IF NOT EXISTS idx_active_warnings_view_user_id ON public.active_warnings_view(user_id);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_employee_id ON public.active_warnings_view(employee_id);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_warning_type ON public.active_warnings_view(warning_type);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_fine_status ON public.active_warnings_view(fine_status);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_task_id ON public.active_warnings_view(task_id);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_assignment_id ON public.active_warnings_view(assignment_id);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_issued_by ON public.active_warnings_view(issued_by);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_issued_at ON public.active_warnings_view(issued_at);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_warning_status ON public.active_warnings_view(warning_status);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_acknowledged_at ON public.active_warnings_view(acknowledged_at);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_acknowledged_by ON public.active_warnings_view(acknowledged_by);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_resolved_at ON public.active_warnings_view(resolved_at);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_resolved_by ON public.active_warnings_view(resolved_by);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_created_at ON public.active_warnings_view(created_at);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_updated_at ON public.active_warnings_view(updated_at);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_branch_id ON public.active_warnings_view(branch_id);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_department_id ON public.active_warnings_view(department_id);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_follow_up_date ON public.active_warnings_view(follow_up_date);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_deleted_at ON public.active_warnings_view(deleted_at);
CREATE INDEX IF NOT EXISTS idx_active_warnings_view_deleted_by ON public.active_warnings_view(deleted_by);

-- Enable Row Level Security
ALTER TABLE public.active_warnings_view ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_active_warnings_view_updated_at
    BEFORE UPDATE ON public.active_warnings_view
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.active_warnings_view IS 'Generated from Aqura schema analysis';
