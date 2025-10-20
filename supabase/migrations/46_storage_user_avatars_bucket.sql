-- Migration: Create storage bucket for user avatars
-- File: 46_storage_user_avatars_bucket.sql
-- Description: Creates the user-avatars storage bucket with policies

BEGIN;

-- Create storage bucket for user avatars
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'user-avatars',
  'user-avatars',
  true,
  NULL, -- No file size restriction
  NULL  -- No MIME type restriction
);

-- Create storage policies for user-avatars bucket
-- Policy: Allow authenticated users to upload avatars
CREATE POLICY "Allow authenticated users to upload avatars" ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'user-avatars' 
  AND auth.role() = 'authenticated'
);

-- Policy: Allow public read access to user avatars
CREATE POLICY "Allow public read access to user avatars" ON storage.objects
FOR SELECT
USING (bucket_id = 'user-avatars');

-- Policy: Allow users to delete their own avatars
CREATE POLICY "Allow users to delete their own avatars" ON storage.objects
FOR DELETE
USING (
  bucket_id = 'user-avatars' 
  AND auth.role() = 'authenticated'
  AND owner = auth.uid()
);

-- Policy: Allow users to update their own avatars
CREATE POLICY "Allow users to update their own avatars" ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'user-avatars' 
  AND auth.role() = 'authenticated'
  AND owner = auth.uid()
)
WITH CHECK (
  bucket_id = 'user-avatars' 
  AND auth.role() = 'authenticated'
);

COMMIT;