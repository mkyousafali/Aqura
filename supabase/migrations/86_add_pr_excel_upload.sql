-- Migration: Add PR Excel Upload functionality
-- This adds a new column to receiving_records table and creates storage bucket for PR Excel files

-- Add new column for PR Excel file URL in receiving_records table (only if it doesn't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'receiving_records' 
                   AND column_name = 'pr_excel_file_url') THEN
        ALTER TABLE receiving_records ADD COLUMN pr_excel_file_url TEXT;
    END IF;
END $$;

-- Add comment to explain the new column
COMMENT ON COLUMN receiving_records.pr_excel_file_url IS 'URL link to uploaded PR Excel file stored in Supabase Storage';

-- Create storage bucket for PR Excel files
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'pr-excel-files',
    'pr-excel-files',
    true,   -- public bucket (same as original-bills)
    52428800,  -- 50MB limit
    ARRAY[
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/excel',
        'application/x-excel',
        'application/x-msexcel',
        'text/csv',
        'application/csv'
    ]
) ON CONFLICT (id) DO NOTHING;

-- Create RLS policies for the PR Excel files bucket (drop existing ones first)
-- Remove any existing policies for pr-excel-files bucket
DROP POLICY IF EXISTS "Allow authenticated users to upload PR Excel files" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to view PR Excel files" ON storage.objects;  
DROP POLICY IF EXISTS "Allow authenticated users to update PR Excel files" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to delete PR Excel files" ON storage.objects;
DROP POLICY IF EXISTS "Allow all operations on pr-excel-files" ON storage.objects;

-- Create a simple, permissive policy for pr-excel-files bucket
CREATE POLICY "Allow all operations on pr-excel-files"
ON storage.objects FOR ALL
USING (bucket_id = 'pr-excel-files')
WITH CHECK (bucket_id = 'pr-excel-files');

-- Create an index on the new column for better query performance
CREATE INDEX IF NOT EXISTS idx_receiving_records_pr_excel_file_url 
ON receiving_records(pr_excel_file_url) 
WHERE pr_excel_file_url IS NOT NULL;

-- Update the updated_at timestamp when pr_excel_file_url is modified
CREATE OR REPLACE FUNCTION update_receiving_records_pr_excel_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.pr_excel_file_url IS DISTINCT FROM NEW.pr_excel_file_url THEN
        NEW.updated_at = now();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for the PR Excel file URL updates
DROP TRIGGER IF EXISTS trigger_update_pr_excel_timestamp ON receiving_records;
CREATE TRIGGER trigger_update_pr_excel_timestamp
    BEFORE UPDATE ON receiving_records
    FOR EACH ROW
    EXECUTE FUNCTION update_receiving_records_pr_excel_timestamp();

-- Add a simple view to check PR Excel file uploads only
CREATE OR REPLACE VIEW receiving_records_pr_excel_status AS
SELECT 
    rr.id,
    rr.bill_number,
    rr.vendor_id,
    v.vendor_name,
    rr.pr_excel_file_url,
    CASE 
        WHEN rr.pr_excel_file_url IS NOT NULL THEN 'Uploaded'
        ELSE 'Not Uploaded'
    END AS pr_excel_status,
    rr.updated_at
FROM receiving_records rr
LEFT JOIN vendors v ON v.erp_vendor_id = rr.vendor_id
ORDER BY rr.updated_at DESC;

-- Add comment to the view
COMMENT ON VIEW receiving_records_pr_excel_status IS 'Simple view showing only PR Excel upload status for receiving records';

-- Create RPC function to count bills without PR Excel files
CREATE OR REPLACE FUNCTION count_bills_without_pr_excel()
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM receiving_records
        WHERE pr_excel_file_url IS NULL 
           OR pr_excel_file_url = ''
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;