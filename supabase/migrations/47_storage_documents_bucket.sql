-- Migration: Create storage bucket for documents
-- File: 47_storage_documents_bucket.sql
-- Description: Creates the documents storage bucket with policies

BEGIN;

-- Create storage bucket for documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'documents',
  'documents',
  true,
  10485760, -- 10 MB in bytes
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']
);

-- Create storage policies for documents bucket
-- Policy: documents_authenticated_delete
CREATE POLICY "documents_authenticated_delete" ON storage.objects
FOR DELETE
USING (
  bucket_id = 'documents' 
  AND auth.role() = 'authenticated'
);

-- Policy: documents_authenticated_insert
CREATE POLICY "documents_authenticated_insert" ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'documents' 
  AND auth.role() = 'authenticated'
);

-- Policy: documents_authenticated_select
CREATE POLICY "documents_authenticated_select" ON storage.objects
FOR SELECT
USING (
  bucket_id = 'documents' 
  AND auth.role() = 'authenticated'
);

-- Policy: documents_authenticated_update
CREATE POLICY "documents_authenticated_update" ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'documents' 
  AND auth.role() = 'authenticated'
)
WITH CHECK (
  bucket_id = 'documents' 
  AND auth.role() = 'authenticated'
);

-- Policy: documents_select_policy (public read access)
CREATE POLICY "documents_select_policy" ON storage.objects
FOR SELECT
USING (bucket_id = 'documents');

-- Policy: documents_upload_policy (public upload access)
CREATE POLICY "documents_upload_policy" ON storage.objects
FOR INSERT
WITH CHECK (bucket_id = 'documents');

COMMIT;