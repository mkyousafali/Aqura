-- Migration for table: expense_scheduler
-- Generated on: 2025-10-30T21:55:45.274Z

CREATE TABLE IF NOT EXISTS public.expense_scheduler (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    branch_id UUID NOT NULL,
    branch_name VARCHAR(255) NOT NULL,
    expense_category_id NUMERIC NOT NULL,
    expense_category_name_en VARCHAR(255) NOT NULL,
    expense_category_name_ar VARCHAR(255) NOT NULL,
    requisition_id JSONB,
    requisition_number JSONB,
    co_user_id UUID NOT NULL,
    co_user_name VARCHAR(255) NOT NULL,
    bill_type VARCHAR(50) NOT NULL,
    bill_number VARCHAR(255) NOT NULL,
    bill_date DATE NOT NULL,
    payment_method VARCHAR(255) NOT NULL,
    due_date TIMESTAMPTZ NOT NULL,
    credit_period JSONB,
    amount DECIMAL(12,2) NOT NULL,
    bill_file_url TEXT NOT NULL,
    description VARCHAR(255) NOT NULL,
    notes JSONB,
    is_paid BOOLEAN DEFAULT true NOT NULL,
    paid_date TIMESTAMPTZ NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_by UUID NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    bank_name JSONB,
    iban JSONB,
    payment_reference VARCHAR(100) NOT NULL,
    schedule_type VARCHAR(50) NOT NULL,
    recurring_type VARCHAR(50),
    recurring_metadata JSONB,
    approver_id UUID NOT NULL,
    approver_name VARCHAR(255) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_expense_scheduler_branch_id ON public.expense_scheduler(branch_id);
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_bill_type ON public.expense_scheduler(bill_type);
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_due_date ON public.expense_scheduler(due_date);
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_paid_date ON public.expense_scheduler(paid_date);
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_status ON public.expense_scheduler(status);
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_created_at ON public.expense_scheduler(created_at);
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_updated_at ON public.expense_scheduler(updated_at);
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_schedule_type ON public.expense_scheduler(schedule_type);
CREATE INDEX IF NOT EXISTS idx_expense_scheduler_recurring_type ON public.expense_scheduler(recurring_type);

-- Enable Row Level Security
ALTER TABLE public.expense_scheduler ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_expense_scheduler_updated_at
    BEFORE UPDATE ON public.expense_scheduler
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.expense_scheduler IS 'Generated from Aqura schema analysis';
