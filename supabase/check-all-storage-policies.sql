-- Check ALL storage policies to see what's blocking uploads
-- Run this in Supabase Dashboard SQL Editor

-- 1. List ALL policies on storage.objects
SELECT 
    policyname,
    cmd,
    roles::text AS roles,
    qual AS using_clause,
    with_check AS with_check_clause
FROM pg_policies
WHERE tablename = 'objects' 
  AND schemaname = 'storage'
ORDER BY policyname;

-- 2. Check if there's a default DENY policy
-- (sometimes Supabase has restrictive default policies)

-- 3. List all buckets
SELECT id, name, public, file_size_limit 
FROM storage.buckets
ORDER BY name;
