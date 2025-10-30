-- Migration for table: vendors
-- Generated on: 2025-10-30T21:55:45.283Z

CREATE TABLE IF NOT EXISTS public.vendors (
    erp_vendor_id NUMERIC NOT NULL,
    vendor_name TEXT NOT NULL,
    salesman_name VARCHAR(255) NOT NULL,
    salesman_contact VARCHAR(255) NOT NULL,
    supervisor_name VARCHAR(255) NOT NULL,
    supervisor_contact VARCHAR(255) NOT NULL,
    vendor_contact_number VARCHAR(255) NOT NULL,
    payment_method VARCHAR(255) NOT NULL,
    credit_period JSONB,
    bank_name VARCHAR(255) NOT NULL,
    iban VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    last_visit JSONB,
    categories JSONB,
    delivery_modes JSONB,
    place JSONB,
    location_link JSONB,
    return_expired_products JSONB,
    return_expired_products_note JSONB,
    return_near_expiry_products JSONB,
    return_near_expiry_products_note JSONB,
    return_over_stock JSONB,
    return_over_stock_note JSONB,
    return_damage_products JSONB,
    return_damage_products_note JSONB,
    no_return BOOLEAN DEFAULT false NOT NULL,
    no_return_note JSONB,
    vat_applicable VARCHAR(255) NOT NULL,
    vat_number JSONB,
    no_vat_note JSONB,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    branch_id UUID NOT NULL,
    payment_priority VARCHAR(255) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_vendors_status ON public.vendors(status);
CREATE INDEX IF NOT EXISTS idx_vendors_created_at ON public.vendors(created_at);
CREATE INDEX IF NOT EXISTS idx_vendors_updated_at ON public.vendors(updated_at);
CREATE INDEX IF NOT EXISTS idx_vendors_branch_id ON public.vendors(branch_id);

-- Enable Row Level Security
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_vendors_updated_at
    BEFORE UPDATE ON public.vendors
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.vendors IS 'Generated from Aqura schema analysis';
