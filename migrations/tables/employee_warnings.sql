-- Migration for table: employee_warnings
-- Generated on: 2025-10-30T21:55:45.295Z

CREATE TABLE IF NOT EXISTS public.employee_warnings (
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
    fine_paid_at JSONB,
    frontend_save_id JSONB,
    fine_payment_note JSONB,
    fine_payment_method VARCHAR(255) NOT NULL,
    fine_payment_reference VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_employee_warnings_user_id ON public.employee_warnings(user_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_employee_id ON public.employee_warnings(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_warning_type ON public.employee_warnings(warning_type);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_fine_status ON public.employee_warnings(fine_status);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_task_id ON public.employee_warnings(task_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_assignment_id ON public.employee_warnings(assignment_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_issued_by ON public.employee_warnings(issued_by);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_issued_at ON public.employee_warnings(issued_at);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_warning_status ON public.employee_warnings(warning_status);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_acknowledged_at ON public.employee_warnings(acknowledged_at);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_acknowledged_by ON public.employee_warnings(acknowledged_by);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_resolved_at ON public.employee_warnings(resolved_at);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_resolved_by ON public.employee_warnings(resolved_by);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_created_at ON public.employee_warnings(created_at);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_updated_at ON public.employee_warnings(updated_at);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_branch_id ON public.employee_warnings(branch_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_department_id ON public.employee_warnings(department_id);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_follow_up_date ON public.employee_warnings(follow_up_date);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_deleted_at ON public.employee_warnings(deleted_at);
CREATE INDEX IF NOT EXISTS idx_employee_warnings_deleted_by ON public.employee_warnings(deleted_by);

-- Enable Row Level Security
ALTER TABLE public.employee_warnings ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_employee_warnings_updated_at
    BEFORE UPDATE ON public.employee_warnings
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.employee_warnings IS 'Generated from Aqura schema analysis';
