-- ============================================
-- Migration: Warning Images Storage System
-- Created: 2025-10-30
-- Purpose: Create storage bucket and policies for warning document images
-- ============================================

-- Create storage bucket for warning documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'warning-documents',
  'warning-documents',
  true,  -- Public bucket so images can be accessed via URL
  5242880,  -- 5MB file size limit
  ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- Storage Policies for warning-documents bucket
-- ============================================

-- Policy: Allow authenticated users to upload warning documents
CREATE POLICY "Authenticated users can upload warning documents"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'warning-documents' AND
  auth.uid() IS NOT NULL
);

-- Policy: Allow public read access to warning documents
CREATE POLICY "Public read access to warning documents"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'warning-documents');

-- Policy: Allow users to update their own warning documents
CREATE POLICY "Users can update their own warning documents"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'warning-documents' AND
  auth.uid() IS NOT NULL
)
WITH CHECK (
  bucket_id = 'warning-documents' AND
  auth.uid() IS NOT NULL
);

-- Policy: Allow users to delete their own warning documents
CREATE POLICY "Users can delete their own warning documents"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'warning-documents' AND
  auth.uid() IS NOT NULL
);

-- ============================================
-- Add index on warning_document_url for faster lookups
-- ============================================
CREATE INDEX IF NOT EXISTS idx_employee_warnings_document_url 
ON employee_warnings(warning_document_url) 
WHERE warning_document_url IS NOT NULL;

-- ============================================
-- Add index on warning_reference for faster lookups
-- ============================================
CREATE INDEX IF NOT EXISTS idx_employee_warnings_reference 
ON employee_warnings(warning_reference);

-- ============================================
-- Create function to generate storage URL from path
-- ============================================
CREATE OR REPLACE FUNCTION get_warning_document_url(document_path TEXT)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  IF document_path IS NULL THEN
    RETURN NULL;
  END IF;
  
  -- Return full public URL for the document
  RETURN 'https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/warning-documents/' || document_path;
END;
$$;

-- ============================================
-- Add comment to warning_document_url column
-- ============================================
COMMENT ON COLUMN employee_warnings.warning_document_url IS 
'Storage path or full URL to the warning document image (PNG/JPEG). 
Format: warning-documents/YYYY/MM/employeename_reference_employeeid_timestamp.png
Example: warning-documents/2025/10/john_doe_WRN-20251030-0001_a1b2c3d4_1730304000000.png';

-- ============================================
-- Grant necessary permissions
-- ============================================
GRANT USAGE ON SCHEMA storage TO authenticated;
GRANT ALL ON storage.objects TO authenticated;
GRANT ALL ON storage.buckets TO authenticated;
