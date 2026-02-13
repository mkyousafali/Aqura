-- Create storage bucket for product request photos
-- Run this in the Supabase SQL Editor

-- Create the storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-request-photos',
  'product-request-photos',
  true,
  20971520,  -- 20MB
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO NOTHING;

-- Allow anyone to read
DROP POLICY IF EXISTS "Allow public read access on product-request-photos" ON storage.objects;
CREATE POLICY "Allow public read access on product-request-photos"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'product-request-photos');

-- Allow anyone to upload (anon + authenticated + service_role)
DROP POLICY IF EXISTS "Allow upload on product-request-photos" ON storage.objects;
CREATE POLICY "Allow upload on product-request-photos"
  ON storage.objects
  FOR INSERT
  WITH CHECK (bucket_id = 'product-request-photos');

-- Allow anyone to update
DROP POLICY IF EXISTS "Allow update on product-request-photos" ON storage.objects;
CREATE POLICY "Allow update on product-request-photos"
  ON storage.objects
  FOR UPDATE
  USING (bucket_id = 'product-request-photos');

-- Allow anyone to delete
DROP POLICY IF EXISTS "Allow delete on product-request-photos" ON storage.objects;
CREATE POLICY "Allow delete on product-request-photos"
  ON storage.objects
  FOR DELETE
  USING (bucket_id = 'product-request-photos');

-- Grant storage access to all roles (CRITICAL per guide)
GRANT ALL ON storage.objects TO anon;
GRANT ALL ON storage.objects TO authenticated;
GRANT ALL ON storage.objects TO service_role;
GRANT ALL ON storage.buckets TO anon;
