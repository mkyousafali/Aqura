-- Migration: Create storage bucket for employee documents
-- File: 45_storage_employee_documents_bucket.sql
-- Description: Creates the employee-documents storage bucket with policies

BEGIN;

-- Create storage bucket for employee documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'employee-documents',
  'employee-documents',
  true,
  52428800, -- 50 MB in bytes
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'application/pdf', 'application/*']
);

-- Create storage policies for employee-documents bucket
-- Policy: Allow authenticated users to delete employee documents
CREATE POLICY "Allow authenticated users to delete employee documents" ON storage.objects
FOR DELETE
USING (
  bucket_id = 'employee-documents' 
  AND auth.role() = 'authenticated'
);

-- Policy: Allow authenticated users to update employee documents
CREATE POLICY "Allow authenticated users to update employee documents" ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'employee-documents' 
  AND auth.role() = 'authenticated'
)
WITH CHECK (
  bucket_id = 'employee-documents' 
  AND auth.role() = 'authenticated'
);

-- Policy: Allow authenticated users to upload employee documents
CREATE POLICY "Allow authenticated users to upload employee documents" ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'employee-documents' 
  AND auth.role() = 'authenticated'
);

-- Policy: Allow authenticated users to view employee documents
CREATE POLICY "Allow authenticated users to view employee documents" ON storage.objects
FOR SELECT
USING (
  bucket_id = 'employee-documents' 
  AND auth.role() = 'authenticated'
);

COMMIT;