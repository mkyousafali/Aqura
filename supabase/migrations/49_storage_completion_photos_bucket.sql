-- Migration: Create storage bucket for completion photos
-- File: 49_storage_completion_photos_bucket.sql
-- Description: Creates the completion-photos storage bucket with policies

BEGIN;

-- Create storage bucket for completion photos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'completion-photos',
  'completion-photos',
  true,
  52428800, -- 50 MB in bytes
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
);

-- Create storage policies for completion-photos bucket
-- Policy: Allow authenticated users to upload completion photos
CREATE POLICY "Allow authenticated users to upload completion photos" ON storage.objects
FOR INSERT
WITH CHECK (bucket_id = 'completion-photos');

-- Policy: Allow users to delete their own completion photos
CREATE POLICY "Allow users to delete their own completion photos" ON storage.objects
FOR DELETE
USING (bucket_id = 'completion-photos');

-- Policy: Allow users to update their own completion photos
CREATE POLICY "Allow users to update their own completion photos" ON storage.objects
FOR UPDATE
USING (bucket_id = 'completion-photos')
WITH CHECK (bucket_id = 'completion-photos');

-- Policy: Allow users to view completion photos
CREATE POLICY "Allow users to view completion photos" ON storage.objects
FOR SELECT
USING (bucket_id = 'completion-photos');

-- Policy: completion_photos_authenticated_delete
CREATE POLICY "completion_photos_authenticated_delete" ON storage.objects
FOR DELETE
USING (
  bucket_id = 'completion-photos' 
  AND auth.role() = 'authenticated'
);

-- Policy: completion_photos_authenticated_insert
CREATE POLICY "completion_photos_authenticated_insert" ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'completion-photos' 
  AND auth.role() = 'authenticated'
);

-- Policy: completion_photos_authenticated_select
CREATE POLICY "completion_photos_authenticated_select" ON storage.objects
FOR SELECT
USING (
  bucket_id = 'completion-photos' 
  AND auth.role() = 'authenticated'
);

-- Policy: completion_photos_authenticated_update
CREATE POLICY "completion_photos_authenticated_update" ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'completion-photos' 
  AND auth.role() = 'authenticated'
)
WITH CHECK (
  bucket_id = 'completion-photos' 
  AND auth.role() = 'authenticated'
);

-- Policy: completion_photos_select_policy (public read access)
CREATE POLICY "completion_photos_select_policy" ON storage.objects
FOR SELECT
USING (bucket_id = 'completion-photos');

-- Policy: completion_photos_upload_policy (public upload access)
CREATE POLICY "completion_photos_upload_policy" ON storage.objects
FOR INSERT
WITH CHECK (bucket_id = 'completion-photos');

-- Policy: Public access to completion photos
CREATE POLICY "Public access to completion photos" ON storage.objects
FOR ALL
USING (bucket_id = 'completion-photos');

COMMIT;