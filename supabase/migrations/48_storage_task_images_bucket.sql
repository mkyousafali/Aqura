-- Migration: Create storage bucket for task images
-- File: 48_storage_task_images_bucket.sql
-- Description: Creates the task-images storage bucket with policies

BEGIN;

-- Create storage bucket for task images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'task-images',
  'task-images',
  true,
  52428800, -- 50 MB in bytes
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml', 'application/pdf']
);

-- Create storage policies for task-images bucket
-- Policy: task_images_authenticated_delete
CREATE POLICY "task_images_authenticated_delete" ON storage.objects
FOR DELETE
USING (
  bucket_id = 'task-images' 
  AND auth.role() = 'authenticated'
);

-- Policy: task_images_authenticated_insert
CREATE POLICY "task_images_authenticated_insert" ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'task-images' 
  AND auth.role() = 'authenticated'
);

-- Policy: task_images_authenticated_select
CREATE POLICY "task_images_authenticated_select" ON storage.objects
FOR SELECT
USING (
  bucket_id = 'task-images' 
  AND auth.role() = 'authenticated'
);

-- Policy: task_images_authenticated_update
CREATE POLICY "task_images_authenticated_update" ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'task-images' 
  AND auth.role() = 'authenticated'
)
WITH CHECK (
  bucket_id = 'task-images' 
  AND auth.role() = 'authenticated'
);

-- Policy: task_images_select_policy (public read access)
CREATE POLICY "task_images_select_policy" ON storage.objects
FOR SELECT
USING (bucket_id = 'task-images');

-- Policy: task_images_upload_policy (public upload access)
CREATE POLICY "task_images_upload_policy" ON storage.objects
FOR INSERT
WITH CHECK (bucket_id = 'task-images');

COMMIT;