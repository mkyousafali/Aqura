-- =====================================================
-- SUPABASE STORAGE BUCKET SETUP FOR EMPLOYEE DOCUMENTS
-- Run this in Supabase SQL Editor
-- =====================================================

-- 1. Create the storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'employee-documents',
  'employee-documents', 
  true, -- Public bucket for file access via URLs
  10485760, -- 10MB file size limit (10 * 1024 * 1024 bytes)
  ARRAY[
    'image/jpeg', 
    'image/jpg', 
    'image/png', 
    'image/webp', 
    'application/pdf', 
    'application/msword', 
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]
) ON CONFLICT (id) DO NOTHING;

-- 2. Drop existing policies first to avoid conflicts
DROP POLICY IF EXISTS "Allow authenticated users to upload employee documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to view employee documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to update employee documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to delete employee documents" ON storage.objects;
DROP POLICY IF EXISTS "Employee documents upload policy" ON storage.objects;
DROP POLICY IF EXISTS "Employee documents select policy" ON storage.objects;
DROP POLICY IF EXISTS "Employee documents update policy" ON storage.objects;
DROP POLICY IF EXISTS "Employee documents delete policy" ON storage.objects;

-- 3. Create storage policies for authenticated users (matching main setup)
CREATE POLICY "Allow authenticated users to upload employee documents" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'employee-documents' AND
  auth.role() = 'authenticated'
);

CREATE POLICY "Allow authenticated users to view employee documents" ON storage.objects
FOR SELECT USING (
  bucket_id = 'employee-documents' AND
  auth.role() = 'authenticated'
);

CREATE POLICY "Allow authenticated users to update employee documents" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'employee-documents' AND
  auth.role() = 'authenticated'
);

CREATE POLICY "Allow authenticated users to delete employee documents" ON storage.objects
FOR DELETE USING (
  bucket_id = 'employee-documents' AND
  auth.role() = 'authenticated'
);

-- 4. Verify bucket creation
SELECT 
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types,
  created_at
FROM storage.buckets 
WHERE id = 'employee-documents';

-- Success message
SELECT 'Storage bucket "employee-documents" created successfully!' as result;