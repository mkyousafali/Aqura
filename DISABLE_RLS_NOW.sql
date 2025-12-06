-- DISABLE RLS - EXECUTE THIS NOW IN SUPABASE SQL EDITOR
-- https://app.supabase.com/project/urbanaqura/sql/new

ALTER TABLE receiving_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_payment_schedule DISABLE ROW LEVEL SECURITY;
ALTER TABLE vendors DISABLE ROW LEVEL SECURITY;
ALTER TABLE branches DISABLE ROW LEVEL SECURITY;

SELECT tablename, rowsecurity FROM pg_tables 
WHERE tablename IN ('receiving_records', 'vendor_payment_schedule', 'vendors', 'branches')
ORDER BY tablename;
