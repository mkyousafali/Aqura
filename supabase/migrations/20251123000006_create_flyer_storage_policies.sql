-- =====================================================
-- Flyer Master: Storage Policies
-- Created: 2025-11-23
-- Description: Creates storage policies for flyer product images bucket
-- =====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Public Access for Flyer Product Images" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can upload flyer product images" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can update flyer product images" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can delete flyer product images" ON storage.objects;

-- Policy 1: Public Access - Anyone can view/download images
CREATE POLICY "Public Access for Flyer Product Images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'flyer-product-images');

-- Policy 2: Public Upload - Anyone can upload images
CREATE POLICY "Anyone can upload flyer product images"
ON storage.objects FOR INSERT
TO public
WITH CHECK (bucket_id = 'flyer-product-images');

-- Policy 3: Public Update - Anyone can update images
CREATE POLICY "Anyone can update flyer product images"
ON storage.objects FOR UPDATE
TO public
USING (bucket_id = 'flyer-product-images')
WITH CHECK (bucket_id = 'flyer-product-images');

-- Policy 4: Public Delete - Anyone can delete images
CREATE POLICY "Anyone can delete flyer product images"
ON storage.objects FOR DELETE
TO public
USING (bucket_id = 'flyer-product-images');
