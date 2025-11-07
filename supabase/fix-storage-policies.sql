-- Fix Storage Policies for customer-app-media bucket
-- Run this in Supabase Dashboard > SQL Editor > New Query

-- ============================================
-- STEP 1: Ensure bucket exists and is public
-- ============================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'customer-app-media',
    'customer-app-media',
    true,
    52428800, -- 50MB limit
    ARRAY['video/mp4', 'video/webm', 'video/quicktime', 'image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 52428800,
    allowed_mime_types = ARRAY['video/mp4', 'video/webm', 'video/quicktime', 'image/jpeg', 'image/png', 'image/webp'];

-- ============================================
-- STEP 2: View ALL existing policies on storage.objects
-- ============================================
SELECT policyname, cmd, roles::text, qual, with_check 
FROM pg_policies 
WHERE tablename = 'objects' AND schemaname = 'storage'
ORDER BY policyname;

-- ============================================
-- STEP 3: Drop ALL existing policies for customer-app-media
-- ============================================
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'objects' 
          AND schemaname = 'storage'
          AND (
              policyname LIKE '%customer-app-media%'
              OR policyname LIKE '%customer_app_media%'
          )
    ) LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', r.policyname);
    END LOOP;
END $$;

-- ============================================
-- STEP 4: Create new simplified policies
-- ============================================

-- Allow ALL operations for authenticated users (no restrictions)
CREATE POLICY "customer-app-media: authenticated full access"
ON storage.objects
FOR ALL
TO authenticated
USING (bucket_id = 'customer-app-media')
WITH CHECK (bucket_id = 'customer-app-media');

-- Allow public SELECT (read) access
CREATE POLICY "customer-app-media: public read access"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'customer-app-media');

-- ============================================
-- STEP 5: Verify new policies
-- ============================================
SELECT 
    policyname,
    cmd,
    roles::text,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'objects' 
  AND schemaname = 'storage'
  AND policyname LIKE '%customer-app-media%'
ORDER BY policyname;
