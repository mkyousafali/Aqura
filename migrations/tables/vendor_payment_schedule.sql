-- Migration for table: vendor_payment_schedule
-- Generated on: 2025-10-30T21:55:45.293Z

CREATE TABLE IF NOT EXISTS public.vendor_payment_schedule (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    receiving_record_id JSONB,
    bill_number VARCHAR(255) NOT NULL,
    vendor_id VARCHAR(255) NOT NULL,
    vendor_name VARCHAR(255) NOT NULL,
    branch_id UUID NOT NULL,
    branch_name VARCHAR(255) NOT NULL,
    bill_date DATE NOT NULL,
    bill_amount DECIMAL(12,2) NOT NULL,
    final_bill_amount DECIMAL(12,2) NOT NULL,
    payment_method VARCHAR(255) NOT NULL,
    bank_name VARCHAR(255) NOT NULL,
    iban VARCHAR(255) NOT NULL,
    due_date TIMESTAMPTZ NOT NULL,
    credit_period NUMERIC NOT NULL,
    vat_number VARCHAR(255) NOT NULL,
    scheduled_date TIMESTAMPTZ NOT NULL,
    paid_date TIMESTAMPTZ,
    notes VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    original_due_date JSONB,
    original_bill_amount DECIMAL(12,2),
    original_final_amount DECIMAL(12,2),
    is_paid BOOLEAN DEFAULT false NOT NULL,
    payment_reference VARCHAR(100),
    task_id UUID,
    task_assignment_id JSONB,
    receiver_user_id JSONB,
    accountant_user_id JSONB,
    verification_status VARCHAR(50) NOT NULL,
    verified_by JSONB,
    verified_date JSONB,
    transaction_date JSONB,
    original_bill_url TEXT,
    created_by JSONB,
    pr_excel_verified BOOLEAN DEFAULT false NOT NULL,
    pr_excel_verified_by JSONB,
    pr_excel_verified_date JSONB,
    discount_amount DECIMAL(12,2) NOT NULL,
    discount_notes JSONB,
    grr_amount DECIMAL(12,2) NOT NULL,
    grr_reference_number VARCHAR(100),
    grr_notes JSONB,
    pri_amount DECIMAL(12,2) NOT NULL,
    pri_reference_number VARCHAR(100),
    pri_notes JSONB,
    last_adjustment_date JSONB,
    last_adjusted_by JSONB,
    adjustment_history JSONB NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_branch_id ON public.vendor_payment_schedule(branch_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_due_date ON public.vendor_payment_schedule(due_date);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_paid_date ON public.vendor_payment_schedule(paid_date);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_created_at ON public.vendor_payment_schedule(created_at);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_updated_at ON public.vendor_payment_schedule(updated_at);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_task_id ON public.vendor_payment_schedule(task_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_verification_status ON public.vendor_payment_schedule(verification_status);

-- Enable Row Level Security
ALTER TABLE public.vendor_payment_schedule ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_vendor_payment_schedule_updated_at
    BEFORE UPDATE ON public.vendor_payment_schedule
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.vendor_payment_schedule IS 'Generated from Aqura schema analysis';
