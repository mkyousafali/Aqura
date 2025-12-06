-- COMPREHENSIVE FIX FOR 401 ERROR
-- Execute this in Supabase SQL editor: https://app.supabase.com/project/urbanaqura/sql/new

-- Step 1: Grant explicit permissions to anon role (REST API uses anon role)
GRANT USAGE ON SCHEMA public TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON receiving_records TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON vendor_payment_schedule TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON vendors TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON branches TO anon;

-- Step 2: Disable RLS on all tables (since we use custom auth, not Supabase Auth)
ALTER TABLE receiving_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_payment_schedule DISABLE ROW LEVEL SECURITY;
ALTER TABLE vendors DISABLE ROW LEVEL SECURITY;
ALTER TABLE branches DISABLE ROW LEVEL SECURITY;

-- Step 3: Verify the changes
SELECT 
  tablename,
  rowsecurity as "RLS Enabled"
FROM pg_tables 
WHERE tablename IN ('receiving_records', 'vendor_payment_schedule', 'vendors', 'branches')
ORDER BY tablename;

-- Step 4: Verify permissions
SELECT 
  grantee, 
  table_name,
  string_agg(privilege_type, ', ') as permissions
FROM information_schema.table_privileges 
WHERE table_name IN ('receiving_records', 'vendor_payment_schedule', 'vendors', 'branches')
GROUP BY grantee, table_name
ORDER BY table_name, grantee;
