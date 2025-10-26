-- Migration: Create Requisitions and Storage Bucket
-- Description: Create requisitions table and storage bucket for expense requisition images

-- Create requisitions table
CREATE TABLE IF NOT EXISTS expense_requisitions (
    id BIGSERIAL PRIMARY KEY,
    requisition_number TEXT NOT NULL UNIQUE,
    branch_id BIGINT NOT NULL,
    branch_name TEXT NOT NULL,
    approver_id BIGINT,
    approver_name TEXT,
    expense_category_id BIGINT REFERENCES expense_sub_categories(id),
    expense_category_name_en TEXT,
    expense_category_name_ar TEXT,
    requester_id TEXT NOT NULL,
    requester_name TEXT NOT NULL,
    requester_contact TEXT NOT NULL,
    vat_applicable BOOLEAN DEFAULT false,
    amount DECIMAL(15, 2) NOT NULL,
    payment_category TEXT NOT NULL,
    credit_period INTEGER,
    bank_name TEXT,
    iban TEXT,
    description TEXT,
    status TEXT DEFAULT 'pending',
    image_url TEXT,
    created_by TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add new columns if they don't exist (for existing tables)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='expense_requisitions' AND column_name='credit_period') THEN
        ALTER TABLE expense_requisitions ADD COLUMN credit_period INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='expense_requisitions' AND column_name='bank_name') THEN
        ALTER TABLE expense_requisitions ADD COLUMN bank_name TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='expense_requisitions' AND column_name='iban') THEN
        ALTER TABLE expense_requisitions ADD COLUMN iban TEXT;
    END IF;
END $$;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_requisitions_branch ON expense_requisitions(branch_id);
CREATE INDEX IF NOT EXISTS idx_requisitions_status ON expense_requisitions(status);
CREATE INDEX IF NOT EXISTS idx_requisitions_created_at ON expense_requisitions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_requisitions_number ON expense_requisitions(requisition_number);

-- Enable Row Level Security (RLS)
ALTER TABLE expense_requisitions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow authenticated users to read requisitions" ON expense_requisitions;
DROP POLICY IF EXISTS "Allow authenticated users to insert requisitions" ON expense_requisitions;
DROP POLICY IF EXISTS "Allow authenticated users to update requisitions" ON expense_requisitions;
DROP POLICY IF EXISTS "Allow authenticated users to delete requisitions" ON expense_requisitions;

-- Create policies for authenticated users
CREATE POLICY "Allow authenticated users to read requisitions"
ON expense_requisitions FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Allow authenticated users to insert requisitions"
ON expense_requisitions FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update requisitions"
ON expense_requisitions FOR UPDATE
TO authenticated
USING (true);

CREATE POLICY "Allow authenticated users to delete requisitions"
ON expense_requisitions FOR DELETE
TO authenticated
USING (true);

-- Create storage bucket for requisition images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'requisition-images',
    'requisition-images',
    true,
    5242880, -- 5MB limit
    ARRAY['image/png', 'image/jpeg', 'image/jpg', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies if they exist
DROP POLICY IF EXISTS "Allow authenticated users to upload requisition images" ON storage.objects;
DROP POLICY IF EXISTS "Allow public to view requisition images" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to update requisition images" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to delete requisition images" ON storage.objects;

-- Create storage policies for requisition images bucket
CREATE POLICY "Allow authenticated users to upload requisition images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'requisition-images');

CREATE POLICY "Allow public to view requisition images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'requisition-images');

CREATE POLICY "Allow authenticated users to update requisition images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'requisition-images');

CREATE POLICY "Allow authenticated users to delete requisition images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'requisition-images');

-- Add comment for documentation
COMMENT ON TABLE expense_requisitions IS 'Expense requisitions with approval workflow and image storage';
COMMENT ON COLUMN expense_requisitions.requisition_number IS 'Unique requisition number in format REQ-YYYYMMDD-XXXX';
COMMENT ON COLUMN expense_requisitions.status IS 'Requisition status: pending, approved, rejected, completed';
COMMENT ON COLUMN expense_requisitions.payment_category IS 'Payment method: advance_cash, advance_bank, advance_cash_credit, advance_bank_credit, cash, bank, cash_credit, bank_credit, stock_purchase_advance_cash, stock_purchase_advance_bank, stock_purchase_cash, stock_purchase_bank';
COMMENT ON COLUMN expense_requisitions.credit_period IS 'Credit period in days (required for credit payment methods: advance_cash_credit, advance_bank_credit, cash_credit, bank_credit)';
COMMENT ON COLUMN expense_requisitions.bank_name IS 'Bank name (optional for all bank payment methods)';
COMMENT ON COLUMN expense_requisitions.iban IS 'IBAN number (optional for all bank payment methods)';
