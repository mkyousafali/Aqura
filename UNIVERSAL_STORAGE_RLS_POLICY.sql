-- UNIVERSAL RLS POLICY FOR STORAGE
-- Execute this to enable RLS on storage buckets

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing storage policies
DROP POLICY IF EXISTS "Allow public read access" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow user uploads" ON storage.objects;
DROP POLICY IF EXISTS "allow_select" ON storage.objects;
DROP POLICY IF EXISTS "allow_insert" ON storage.objects;
DROP POLICY IF EXISTS "allow_update" ON storage.objects;
DROP POLICY IF EXISTS "allow_delete" ON storage.objects;

-- Create universal PERMISSIVE policies for storage
-- SELECT policy - allow everyone to read
CREATE POLICY "allow_select" ON storage.objects FOR SELECT USING (true);

-- INSERT policy - allow everyone to upload
CREATE POLICY "allow_insert" ON storage.objects FOR INSERT WITH CHECK (true);

-- UPDATE policy - allow everyone to update metadata
CREATE POLICY "allow_update" ON storage.objects FOR UPDATE USING (true) WITH CHECK (true);

-- DELETE policy - allow everyone to delete
CREATE POLICY "allow_delete" ON storage.objects FOR DELETE USING (true);

-- Verify storage policies
SELECT 
  policyname,
  action,
  permissive
FROM pg_policies 
WHERE tablename = 'objects'
ORDER BY policyname;
