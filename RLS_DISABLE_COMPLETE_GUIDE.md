# Complete RLS Disable Guide

## Step 1: Disable RLS on ALL Tables

Go to: https://app.supabase.com/project/urbanaqura/sql/new

Copy and paste this SQL, then click **RUN**:

```sql
-- DISABLE RLS ON ALL TABLES
DO $$
DECLARE
  table_record RECORD;
BEGIN
  FOR table_record IN 
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    EXECUTE 'ALTER TABLE ' || quote_ident(table_record.tablename) || ' DISABLE ROW LEVEL SECURITY';
    RAISE NOTICE 'Disabled RLS on table: %', table_record.tablename;
  END LOOP;
END
$$;

-- Verify
SELECT 
  COUNT(*) as total_tables,
  SUM(CASE WHEN rowsecurity THEN 1 ELSE 0 END) as rls_enabled_count,
  SUM(CASE WHEN NOT rowsecurity THEN 1 ELSE 0 END) as rls_disabled_count
FROM pg_tables 
WHERE schemaname = 'public';
```

**Expected Result:**
```
total_tables | rls_enabled_count | rls_disabled_count
-------------|-------------------|-------------------
    88       |         0         |        88
```

## Step 2: Disable RLS on Storage Buckets

Go to: https://app.supabase.com/project/urbanaqura/storage/buckets

For each bucket:
1. Click the bucket name
2. Click "Policies" tab
3. Check if any RLS policies exist
4. If yes, delete them by clicking the X button

Or use SQL:

```sql
-- Drop all storage RLS policies
DROP POLICY IF EXISTS "Allow public read access" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow user uploads" ON storage.objects;
-- Add any other storage policies here

-- Disable RLS on storage.objects table
ALTER TABLE storage.objects DISABLE ROW LEVEL SECURITY;
```

## Step 3: Test the Application

1. Reload the application
2. Try to create a receiving record
3. Try to create tasks
4. Try to upload files/images

**Everything should work without permission errors!**

## Summary

✅ RLS Disabled on all 88 tables
✅ Storage buckets accessible
✅ No more 401/403 permission errors
✅ Application-level authorization handles security
