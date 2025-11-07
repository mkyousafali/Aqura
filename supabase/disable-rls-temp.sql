-- TEMPORARY: Disable RLS for testing
-- This will help us identify if RLS is the issue

-- Disable RLS entirely on storage.objects (TEMPORARY - for testing only)
ALTER TABLE storage.objects DISABLE ROW LEVEL SECURITY;

-- Verify RLS is disabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'storage' AND tablename = 'objects';

-- TEST UPLOAD NOW - if it works, the issue is with policies

-- ============================================
-- After confirming upload works, re-enable RLS:
-- ============================================
-- ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Then apply these working policies:
/*
CREATE POLICY "customer-app-media: authenticated full access"
ON storage.objects
FOR ALL
TO authenticated
USING (bucket_id = 'customer-app-media')
WITH CHECK (bucket_id = 'customer-app-media');

CREATE POLICY "customer-app-media: public read access"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'customer-app-media');
*/
