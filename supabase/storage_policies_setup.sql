-- Alternative approach: Make bucket public and disable RLS for easier access
-- This removes authentication requirements for the original-bills bucket

-- First, check if storage.objects has RLS enabled
SELECT relname, relrowsecurity 
FROM pg_class 
WHERE relname = 'objects' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'storage');

-- Option 1: Disable RLS entirely on storage.objects (if you have permission)
-- ALTER TABLE storage.objects DISABLE ROW LEVEL SECURITY;

-- Option 2: Create a simple public policy (try this first)
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
CREATE POLICY "Public Access" ON storage.objects 
FOR ALL 
TO public 
USING (bucket_id = 'original-bills')
WITH CHECK (bucket_id = 'original-bills');

-- Option 3: If the above doesn't work, try creating policies for anon users
DROP POLICY IF EXISTS "Allow anon users to upload original bills" ON storage.objects;
CREATE POLICY "Allow anon users to upload original bills" ON storage.objects
FOR INSERT 
TO anon, authenticated
WITH CHECK (bucket_id = 'original-bills');

DROP POLICY IF EXISTS "Allow anon users to view original bills" ON storage.objects;
CREATE POLICY "Allow anon users to view original bills" ON storage.objects
FOR SELECT 
TO anon, authenticated
USING (bucket_id = 'original-bills');

DROP POLICY IF EXISTS "Allow anon users to update original bills" ON storage.objects;
CREATE POLICY "Allow anon users to update original bills" ON storage.objects
FOR UPDATE 
TO anon, authenticated
USING (bucket_id = 'original-bills')
WITH CHECK (bucket_id = 'original-bills');

DROP POLICY IF EXISTS "Allow anon users to delete original bills" ON storage.objects;
CREATE POLICY "Allow anon users to delete original bills" ON storage.objects
FOR DELETE 
TO anon, authenticated
USING (bucket_id = 'original-bills');

-- Verify policies were created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage';