-- Migration: Create storage bucket for notification images
-- File: 50_storage_notification_images_bucket.sql
-- Description: Creates the notification-images storage bucket with policies

BEGIN;

-- Create storage bucket for notification images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'notification-images',
  'notification-images',
  true,
  52428800, -- 50 MB in bytes
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml', 'application/pdf']
);

-- Create storage policies for notification-images bucket
-- Policy: Allow authenticated users to upload notification images
CREATE POLICY "Allow authenticated users to upload notification images" ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'notification-images' 
  AND auth.role() = 'authenticated'
);

-- Policy: Allow public read access to notification images
CREATE POLICY "Allow public read access to notification images" ON storage.objects
FOR SELECT
USING (bucket_id = 'notification-images');

-- Policy: Allow users to delete their own notification images
CREATE POLICY "Allow users to delete their own notification images" ON storage.objects
FOR DELETE
USING (
  bucket_id = 'notification-images' 
  AND auth.role() = 'authenticated'
);

COMMIT;