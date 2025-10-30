-- Migration for table: receiving_records_pr_excel_status
-- Generated on: 2025-10-30T21:55:45.329Z

CREATE TABLE IF NOT EXISTS public.receiving_records_pr_excel_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    bill_number VARCHAR(255) NOT NULL,
    vendor_id NUMERIC NOT NULL,
    vendor_name VARCHAR(255) NOT NULL,
    pr_excel_file_url TEXT,
    pr_excel_status VARCHAR(50) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_receiving_records_pr_excel_status_pr_excel_status ON public.receiving_records_pr_excel_status(pr_excel_status);
CREATE INDEX IF NOT EXISTS idx_receiving_records_pr_excel_status_updated_at ON public.receiving_records_pr_excel_status(updated_at);

-- Enable Row Level Security
ALTER TABLE public.receiving_records_pr_excel_status ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_receiving_records_pr_excel_status_updated_at
    BEFORE UPDATE ON public.receiving_records_pr_excel_status
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.receiving_records_pr_excel_status IS 'Generated from Aqura schema analysis';
