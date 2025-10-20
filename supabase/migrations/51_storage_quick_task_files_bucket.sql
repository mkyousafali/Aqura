-- Migration: Create storage bucket for quick task files
-- File: 51_storage_quick_task_files_bucket.sql
-- Description: Creates the quick-task-files storage bucket with policies

BEGIN;

-- Create storage bucket for quick task files
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'quick-task-files',
  'quick-task-files',
  true,
  52428800, -- 50 MB in bytes
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'application/pdf', 'application/*']
);

-- Create storage policies for quick-task-files bucket
-- Policy: Users can delete quick task files
CREATE POLICY "Users can delete quick task files" ON storage.objects
FOR DELETE
USING (bucket_id = 'quick-task-files');

-- Policy: Users can update their quick task files
CREATE POLICY "Users can update their quick task files" ON storage.objects
FOR UPDATE
USING (bucket_id = 'quick-task-files')
WITH CHECK (bucket_id = 'quick-task-files');

-- Policy: Users can upload quick task files
CREATE POLICY "Users can upload quick task files" ON storage.objects
FOR INSERT
WITH CHECK (bucket_id = 'quick-task-files');

-- Policy: Users can view quick task files
CREATE POLICY "Users can view quick task files" ON storage.objects
FOR SELECT
USING (bucket_id = 'quick-task-files');

COMMIT;