-- Migration for table: receiving_records
-- Generated on: 2025-10-30T21:55:45.292Z

CREATE TABLE IF NOT EXISTS public.receiving_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    user_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    vendor_id NUMERIC NOT NULL,
    bill_date DATE NOT NULL,
    bill_amount DECIMAL(12,2) NOT NULL,
    bill_number VARCHAR(255) NOT NULL,
    payment_method VARCHAR(255) NOT NULL,
    credit_period JSONB,
    due_date TIMESTAMPTZ NOT NULL,
    bank_name VARCHAR(255) NOT NULL,
    iban VARCHAR(255) NOT NULL,
    vendor_vat_number VARCHAR(255) NOT NULL,
    bill_vat_number VARCHAR(255) NOT NULL,
    vat_numbers_match BOOLEAN DEFAULT true NOT NULL,
    vat_mismatch_reason JSONB,
    branch_manager_user_id UUID NOT NULL,
    shelf_stocker_user_ids JSONB NOT NULL,
    accountant_user_id UUID NOT NULL,
    purchasing_manager_user_id UUID NOT NULL,
    expired_return_amount DECIMAL(12,2) NOT NULL,
    near_expiry_return_amount DECIMAL(12,2) NOT NULL,
    over_stock_return_amount DECIMAL(12,2) NOT NULL,
    damage_return_amount DECIMAL(12,2) NOT NULL,
    total_return_amount DECIMAL(12,2) NOT NULL,
    final_bill_amount DECIMAL(12,2) NOT NULL,
    expired_erp_document_type VARCHAR(50),
    expired_erp_document_number JSONB,
    expired_vendor_document_number JSONB,
    near_expiry_erp_document_type VARCHAR(50),
    near_expiry_erp_document_number JSONB,
    near_expiry_vendor_document_number JSONB,
    over_stock_erp_document_type VARCHAR(50),
    over_stock_erp_document_number JSONB,
    over_stock_vendor_document_number JSONB,
    damage_erp_document_type VARCHAR(50),
    damage_erp_document_number JSONB,
    damage_vendor_document_number JSONB,
    has_expired_returns BOOLEAN DEFAULT false NOT NULL,
    has_near_expiry_returns BOOLEAN DEFAULT false NOT NULL,
    has_over_stock_returns BOOLEAN DEFAULT false NOT NULL,
    has_damage_returns BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    inventory_manager_user_id UUID NOT NULL,
    night_supervisor_user_ids JSONB NOT NULL,
    warehouse_handler_user_ids JSONB NOT NULL,
    certificate_url TEXT NOT NULL,
    certificate_generated_at DECIMAL(12,2) NOT NULL,
    certificate_file_name TEXT NOT NULL,
    original_bill_url TEXT NOT NULL,
    erp_purchase_invoice_reference VARCHAR(100) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    pr_excel_file_url TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_receiving_records_user_id ON public.receiving_records(user_id);
CREATE INDEX IF NOT EXISTS idx_receiving_records_branch_id ON public.receiving_records(branch_id);
CREATE INDEX IF NOT EXISTS idx_receiving_records_due_date ON public.receiving_records(due_date);
CREATE INDEX IF NOT EXISTS idx_receiving_records_expired_erp_document_type ON public.receiving_records(expired_erp_document_type);
CREATE INDEX IF NOT EXISTS idx_receiving_records_near_expiry_erp_document_type ON public.receiving_records(near_expiry_erp_document_type);
CREATE INDEX IF NOT EXISTS idx_receiving_records_over_stock_erp_document_type ON public.receiving_records(over_stock_erp_document_type);
CREATE INDEX IF NOT EXISTS idx_receiving_records_damage_erp_document_type ON public.receiving_records(damage_erp_document_type);
CREATE INDEX IF NOT EXISTS idx_receiving_records_created_at ON public.receiving_records(created_at);
CREATE INDEX IF NOT EXISTS idx_receiving_records_updated_at ON public.receiving_records(updated_at);

-- Enable Row Level Security
ALTER TABLE public.receiving_records ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_receiving_records_updated_at
    BEFORE UPDATE ON public.receiving_records
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.receiving_records IS 'Generated from Aqura schema analysis';
