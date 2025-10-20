-- Migration: Create storage bucket for clearance certificates
-- File: 52_storage_clearance_certificates_bucket.sql
-- Description: Creates the clearance-certificates storage bucket with policies

BEGIN;

-- Create storage bucket for clearance certificates
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'clearance-certificates',
  'clearance-certificates',
  true,
  10485760, -- 10 MB in bytes
  ARRAY['image/png', 'image/jpeg', 'application/pdf']
);

-- Create storage policies for clearance-certificates bucket
-- Policy: Allow certificate deletion
CREATE POLICY "Allow certificate deletion" ON storage.objects
FOR DELETE
USING (bucket_id = 'clearance-certificates');

-- Policy: Allow certificate updates
CREATE POLICY "Allow certificate updates" ON storage.objects
FOR UPDATE
USING (bucket_id = 'clearance-certificates')
WITH CHECK (bucket_id = 'clearance-certificates');

-- Policy: Allow certificate uploads
CREATE POLICY "Allow certificate uploads" ON storage.objects
FOR INSERT
WITH CHECK (bucket_id = 'clearance-certificates');

-- Policy: Allow certificate viewing
CREATE POLICY "Allow certificate viewing" ON storage.objects
FOR SELECT
USING (bucket_id = 'clearance-certificates');

COMMIT;