-- Migration for table: non_approved_payment_scheduler
-- Generated on: 2025-10-30T21:55:45.303Z

CREATE TABLE IF NOT EXISTS public.non_approved_payment_scheduler (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    schedule_type VARCHAR(50) NOT NULL,
    branch_id UUID NOT NULL,
    branch_name VARCHAR(255) NOT NULL,
    expense_category_id NUMERIC NOT NULL,
    expense_category_name_en VARCHAR(255) NOT NULL,
    expense_category_name_ar VARCHAR(255) NOT NULL,
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
    bank_name JSONB,
    iban JSONB,
    description VARCHAR(255) NOT NULL,
    notes JSONB,
    recurring_type VARCHAR(50),
    recurring_metadata JSONB,
    approver_id UUID NOT NULL,
    approver_name VARCHAR(255) NOT NULL,
    approval_status VARCHAR(50) NOT NULL,
    approved_at JSONB,
    approved_by JSONB,
    rejection_reason JSONB,
    expense_scheduler_id JSONB,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_by JSONB,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_non_approved_payment_scheduler_schedule_type ON public.non_approved_payment_scheduler(schedule_type);
CREATE INDEX IF NOT EXISTS idx_non_approved_payment_scheduler_branch_id ON public.non_approved_payment_scheduler(branch_id);
CREATE INDEX IF NOT EXISTS idx_non_approved_payment_scheduler_bill_type ON public.non_approved_payment_scheduler(bill_type);
CREATE INDEX IF NOT EXISTS idx_non_approved_payment_scheduler_due_date ON public.non_approved_payment_scheduler(due_date);
CREATE INDEX IF NOT EXISTS idx_non_approved_payment_scheduler_recurring_type ON public.non_approved_payment_scheduler(recurring_type);
CREATE INDEX IF NOT EXISTS idx_non_approved_payment_scheduler_approval_status ON public.non_approved_payment_scheduler(approval_status);
CREATE INDEX IF NOT EXISTS idx_non_approved_payment_scheduler_created_at ON public.non_approved_payment_scheduler(created_at);
CREATE INDEX IF NOT EXISTS idx_non_approved_payment_scheduler_updated_at ON public.non_approved_payment_scheduler(updated_at);

-- Enable Row Level Security
ALTER TABLE public.non_approved_payment_scheduler ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_non_approved_payment_scheduler_updated_at
    BEFORE UPDATE ON public.non_approved_payment_scheduler
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.non_approved_payment_scheduler IS 'Generated from Aqura schema analysis';
