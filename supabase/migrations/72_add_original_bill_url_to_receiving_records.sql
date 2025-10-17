-- Add original_bill_url column to receiving_records table (if it doesn't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'receiving_records' 
        AND column_name = 'original_bill_url'
    ) THEN
        ALTER TABLE receiving_records ADD COLUMN original_bill_url TEXT;
    END IF;
END $$;

-- Create index for original_bill_url for better query performance (if it doesn't exist)
CREATE INDEX IF NOT EXISTS idx_receiving_records_original_bill_url ON receiving_records(original_bill_url);

-- Add comment for documentation
COMMENT ON COLUMN receiving_records.original_bill_url IS 'URL to uploaded original bill document (PDF, image, etc.)';

-- Create storage bucket for original bills if it doesn't exist
-- Create the original-bills bucket for storing uploaded bill documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'original-bills',
    'original-bills',
    true,
    52428800, -- 50MB limit
    ARRAY['application/pdf', 'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/bmp', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- Note: Storage policies for RLS need to be set up through the Supabase dashboard
-- or using the storage.create_policy function if available.
-- 
-- In the Supabase dashboard, go to Storage > Policies and create policies for 'original-bills' bucket:
-- 1. Policy for INSERT: Allow authenticated users to upload to 'original-bills' bucket
-- 2. Policy for SELECT: Allow authenticated users to view files in 'original-bills' bucket
-- 3. Policy for UPDATE: Allow authenticated users to update files in 'original-bills' bucket  
-- 4. Policy for DELETE: Allow authenticated users to delete files in 'original-bills' bucket
--
-- Policy conditions should be: bucket_id = 'original-bills' AND auth.role() = 'authenticated'

-- Update RLS policies to include the new column (existing policies should cover it)
-- The existing SELECT, INSERT, UPDATE policies will automatically include the new column