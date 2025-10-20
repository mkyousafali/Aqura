-- Migration: Create storage bucket for original bills
-- File: 53_storage_original_bills_bucket.sql
-- Description: Creates the original-bills storage bucket with policies

BEGIN;

-- Create storage bucket for original bills
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'original-bills',
  'original-bills',
  true,
  52428800, -- 50 MB in bytes
  ARRAY['application/pdf', 'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/*']
);

-- Create storage policies for original-bills bucket
-- Policy: Allow anon users to delete original bills
CREATE POLICY "Allow anon users to delete original bills" ON storage.objects
FOR DELETE
USING (
  bucket_id = 'original-bills' 
  AND (auth.role() = 'anon' OR auth.role() = 'authenticated')
);

-- Policy: Allow anon users to update original bills
CREATE POLICY "Allow anon users to update original bills" ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'original-bills' 
  AND (auth.role() = 'anon' OR auth.role() = 'authenticated')
)
WITH CHECK (
  bucket_id = 'original-bills' 
  AND (auth.role() = 'anon' OR auth.role() = 'authenticated')
);

-- Policy: Allow anon users to upload original bills
CREATE POLICY "Allow anon users to upload original bills" ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'original-bills' 
  AND (auth.role() = 'anon' OR auth.role() = 'authenticated')
);

-- Policy: Allow anon users to view original bills
CREATE POLICY "Allow anon users to view original bills" ON storage.objects
FOR SELECT
USING (
  bucket_id = 'original-bills' 
  AND (auth.role() = 'anon' OR auth.role() = 'authenticated')
);

-- Policy: Public Access
CREATE POLICY "Public Access" ON storage.objects
FOR ALL
USING (bucket_id = 'original-bills');

COMMIT;