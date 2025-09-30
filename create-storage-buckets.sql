-- Create storage buckets for the Aqura task management system
-- This script should be run in the Supabase SQL editor

-- Note: The storage extension is already available in Supabase
-- No need to create the extension manually

-- Create task-images bucket for task creation images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'task-images',
  'task-images', 
  false,
  5242880, -- 5MB
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- Create completion-photos bucket for task completion photos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'completion-photos',
  'completion-photos',
  false,
  5242880, -- 5MB
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- Create documents bucket for general document uploads
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'documents',
  'documents',
  false,
  10485760, -- 10MB
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'text/plain']
) ON CONFLICT (id) DO NOTHING;

-- Enable Row Level Security on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Policies for task-images bucket
DROP POLICY IF EXISTS "Allow authenticated users to upload task images" ON storage.objects;
CREATE POLICY "Allow authenticated users to upload task images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'task-images');

DROP POLICY IF EXISTS "Allow authenticated users to view task images" ON storage.objects;
CREATE POLICY "Allow authenticated users to view task images"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'task-images');

DROP POLICY IF EXISTS "Allow users to update their own task images" ON storage.objects;
CREATE POLICY "Allow users to update their own task images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'task-images');

DROP POLICY IF EXISTS "Allow users to delete their own task images" ON storage.objects;
CREATE POLICY "Allow users to delete their own task images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'task-images');

-- Policies for completion-photos bucket
DROP POLICY IF EXISTS "Allow authenticated users to upload completion photos" ON storage.objects;
CREATE POLICY "Allow authenticated users to upload completion photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'completion-photos');

DROP POLICY IF EXISTS "Allow authenticated users to view completion photos" ON storage.objects;
CREATE POLICY "Allow authenticated users to view completion photos"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'completion-photos');

DROP POLICY IF EXISTS "Allow users to update completion photos" ON storage.objects;
CREATE POLICY "Allow users to update completion photos"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'completion-photos');

DROP POLICY IF EXISTS "Allow users to delete completion photos" ON storage.objects;
CREATE POLICY "Allow users to delete completion photos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'completion-photos');

-- Policies for documents bucket
DROP POLICY IF EXISTS "Allow authenticated users to upload documents" ON storage.objects;
CREATE POLICY "Allow authenticated users to upload documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'documents');

DROP POLICY IF EXISTS "Allow authenticated users to view documents" ON storage.objects;
CREATE POLICY "Allow authenticated users to view documents"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'documents');

DROP POLICY IF EXISTS "Allow users to update their own documents" ON storage.objects;
CREATE POLICY "Allow users to update their own documents"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'documents');

DROP POLICY IF EXISTS "Allow users to delete their own documents" ON storage.objects;
CREATE POLICY "Allow users to delete their own documents"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'documents');

-- Create a function to help with file management
CREATE OR REPLACE FUNCTION public.get_file_url(bucket_name text, file_path text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN concat('https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/', bucket_name, '/', file_path);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_file_url(text, text) TO authenticated;

-- Verify buckets were created
SELECT 
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types,
  created_at
FROM storage.buckets
WHERE id IN ('task-images', 'completion-photos', 'documents')
ORDER BY created_at;