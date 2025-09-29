-- =====================================================
-- DIAGNOSE STORAGE SETUP ISSUES
-- Run this in Supabase SQL Editor to check current state
-- =====================================================

-- 1. Check if storage bucket exists
SELECT 'STORAGE BUCKET STATUS:' as check_type;
SELECT 
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types,
  created_at
FROM storage.buckets 
WHERE id = 'employee-documents';

-- 2. Check current storage policies
SELECT 'STORAGE POLICIES STATUS:' as check_type;
SELECT 
    schemaname,
    tablename, 
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage'
AND (policyname LIKE '%employee%' OR policyname LIKE '%document%');

-- 3. Check if hr_employee_documents table exists
SELECT 'HR DOCUMENTS TABLE STATUS:' as check_type;
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'hr_employee_documents' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 4. Check table policies  
SELECT 'TABLE POLICIES STATUS:' as check_type;
SELECT 
    schemaname,
    tablename, 
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies 
WHERE tablename = 'hr_employee_documents' 
AND schemaname = 'public';

-- 5. Check authentication status (run this when logged in)
SELECT 'AUTHENTICATION STATUS:' as check_type;
SELECT 
  auth.uid() as user_id,
  auth.role() as user_role,
  auth.jwt() -> 'email' as user_email;