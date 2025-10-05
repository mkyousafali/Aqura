-- Create notification-images bucket for storing notification attachments
-- This should be run in Supabase SQL Editor

-- Insert the bucket configuration
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'notification-images',
    'notification-images', 
    true,
    5242880, -- 5MB in bytes
    ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
);

-- Create RLS policy to allow authenticated users to upload
CREATE POLICY "Allow authenticated users to upload notification images" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'notification-images');

-- Create RLS policy to allow public read access
CREATE POLICY "Allow public read access to notification images" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'notification-images');

-- Create RLS policy to allow users to delete their own uploads
CREATE POLICY "Allow users to delete their own notification images" ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'notification-images' AND auth.uid()::text = (storage.foldername(name))[1]);