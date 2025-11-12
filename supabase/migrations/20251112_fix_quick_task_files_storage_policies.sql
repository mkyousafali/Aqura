-- Fix RLS policies for quick-task-files storage bucket
-- This allows authenticated users to upload files for quick task completions

-- Drop existing policies if any
DROP POLICY IF EXISTS "Authenticated users can upload quick task files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can view quick task files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update quick task files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete quick task files" ON storage.objects;
DROP POLICY IF EXISTS "Public can view quick task files" ON storage.objects;

-- Allow authenticated users to insert (upload) files to quick-task-files bucket
CREATE POLICY "Authenticated users can upload quick task files"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'quick-task-files');

-- Allow authenticated users to view their uploaded files
CREATE POLICY "Authenticated users can view quick task files"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'quick-task-files');

-- Allow authenticated users to update their uploaded files
CREATE POLICY "Authenticated users can update quick task files"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'quick-task-files');

-- Allow authenticated users to delete their uploaded files
CREATE POLICY "Authenticated users can delete quick task files"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'quick-task-files');

-- Allow public access to view quick task files (since bucket is public)
CREATE POLICY "Public can view quick task files"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'quick-task-files');
