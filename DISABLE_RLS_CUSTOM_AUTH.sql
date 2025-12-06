-- DISABLE RLS on tables since we're using custom authentication
-- This is safe because we have proper application-level authorization checks
-- and don't rely on Supabase Auth for user identification

-- Disable RLS on receiving_records
ALTER TABLE receiving_records DISABLE ROW LEVEL SECURITY;

-- Disable RLS on vendor_payment_schedule
ALTER TABLE vendor_payment_schedule DISABLE ROW LEVEL SECURITY;

-- Disable RLS on vendors
ALTER TABLE vendors DISABLE ROW LEVEL SECURITY;

-- Disable RLS on branches
ALTER TABLE branches DISABLE ROW LEVEL SECURITY;

-- Verify RLS is disabled
SELECT 
  tablename,
  rowsecurity as "RLS Enabled"
FROM pg_tables 
WHERE tablename IN ('receiving_records', 'vendor_payment_schedule', 'vendors', 'branches')
ORDER BY tablename;
