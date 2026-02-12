-- Create storage bucket for asset invoices
-- Run this in the Supabase SQL Editor

-- Create the storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES (
    'asset-invoices',
    'asset-invoices',
    true,
    52428800 -- 50MB limit
)
ON CONFLICT (id) DO NOTHING;

-- Allow anyone to read
DROP POLICY IF EXISTS "Public read access for asset invoices" ON storage.objects;
CREATE POLICY "Public read access for asset invoices"
    ON storage.objects
    FOR SELECT
    USING (bucket_id = 'asset-invoices');

-- Allow anyone to upload (anon + authenticated + service_role)
DROP POLICY IF EXISTS "Allow upload for asset invoices" ON storage.objects;
CREATE POLICY "Allow upload for asset invoices"
    ON storage.objects
    FOR INSERT
    WITH CHECK (bucket_id = 'asset-invoices');

-- Allow anyone to update
DROP POLICY IF EXISTS "Allow update for asset invoices" ON storage.objects;
CREATE POLICY "Allow update for asset invoices"
    ON storage.objects
    FOR UPDATE
    USING (bucket_id = 'asset-invoices');

-- Allow anyone to delete
DROP POLICY IF EXISTS "Allow delete for asset invoices" ON storage.objects;
CREATE POLICY "Allow delete for asset invoices"
    ON storage.objects
    FOR DELETE
    USING (bucket_id = 'asset-invoices');

-- Grant storage access to all roles (CRITICAL per guide)
GRANT ALL ON storage.objects TO anon;
GRANT ALL ON storage.objects TO authenticated;
GRANT ALL ON storage.objects TO service_role;
GRANT ALL ON storage.buckets TO anon;
GRANT ALL ON storage.buckets TO authenticated;
GRANT ALL ON storage.buckets TO service_role;
