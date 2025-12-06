-- DISABLE RLS ON ALL TABLES AND STORAGE
-- Execute this in Supabase SQL editor: https://app.supabase.com/project/urbanaqura/sql/new

-- Step 1: Disable RLS on ALL tables in public schema
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

-- Step 2: Verify RLS is disabled on all tables
SELECT 
  COUNT(*) as total_tables,
  SUM(CASE WHEN rowsecurity THEN 1 ELSE 0 END) as rls_enabled_count,
  SUM(CASE WHEN NOT rowsecurity THEN 1 ELSE 0 END) as rls_disabled_count
FROM pg_tables 
WHERE schemaname = 'public';

-- Step 3: List all tables with their RLS status
SELECT 
  tablename,
  rowsecurity as "RLS Enabled"
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;
