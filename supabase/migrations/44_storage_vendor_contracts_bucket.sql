-- Migration: Create storage bucket for vendor contracts
-- File: 44_storage_vendor_contracts_bucket.sql
-- Description: Creates the vendor-contracts storage bucket with policies

BEGIN;

-- Create storage bucket for vendor contracts
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'vendor-contracts',
  'vendor-contracts',
  true,
  52428800, -- 50 MB in bytes
  ARRAY['application/pdf', 'image/*']
);

-- Create storage policies for vendor-contracts bucket
-- Policy: Authenticated users can upload contract files
CREATE POLICY "Authenticated users can upload contract files" ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'vendor-contracts' 
  AND auth.role() = 'authenticated'
);

-- Policy: Authenticated users can view contract files
CREATE POLICY "Authenticated users can view contract files" ON storage.objects
FOR SELECT
USING (
  bucket_id = 'vendor-contracts' 
  AND auth.role() = 'authenticated'
);

-- Policy: Users can delete their own contract files
CREATE POLICY "Users can delete their own contract files" ON storage.objects
FOR DELETE
USING (
  bucket_id = 'vendor-contracts' 
  AND auth.role() = 'authenticated'
  AND owner = auth.uid()
);

-- Policy: Users can update their own contract files
CREATE POLICY "Users can update their own contract files" ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'vendor-contracts' 
  AND auth.role() = 'authenticated'
  AND owner = auth.uid()
)
WITH CHECK (
  bucket_id = 'vendor-contracts' 
  AND auth.role() = 'authenticated'
);

COMMIT;