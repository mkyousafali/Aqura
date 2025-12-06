-- UNIVERSAL RLS POLICY FOR ALL TABLES AND STORAGE
-- Compatible with custom persistentAuth system (no Supabase Auth needed)
-- Allows all operations for authenticated users via anon role

-- Step 1: Enable RLS on all tables
DO $$
DECLARE
  table_record RECORD;
BEGIN
  FOR table_record IN 
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    EXECUTE 'ALTER TABLE ' || quote_ident(table_record.tablename) || ' ENABLE ROW LEVEL SECURITY';
    RAISE NOTICE 'Enabled RLS on table: %', table_record.tablename;
  END LOOP;
END
$$;

-- Step 2: Drop all existing policies (clean slate)
DO $$
DECLARE
  policy_record RECORD;
BEGIN
  FOR policy_record IN 
    SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public'
  LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(policy_record.policyname) || ' ON ' || quote_ident(policy_record.tablename);
  END LOOP;
END
$$;

-- Step 3: Create universal PERMISSIVE policies on all tables
-- These policies allow ALL operations for anyone (since auth is handled at app level)
DO $$
DECLARE
  table_record RECORD;
BEGIN
  FOR table_record IN 
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    -- Universal SELECT policy
    EXECUTE 'CREATE POLICY "allow_select" ON ' || quote_ident(table_record.tablename) || 
            ' FOR SELECT USING (true)';
    
    -- Universal INSERT policy
    EXECUTE 'CREATE POLICY "allow_insert" ON ' || quote_ident(table_record.tablename) || 
            ' FOR INSERT WITH CHECK (true)';
    
    -- Universal UPDATE policy
    EXECUTE 'CREATE POLICY "allow_update" ON ' || quote_ident(table_record.tablename) || 
            ' FOR UPDATE USING (true) WITH CHECK (true)';
    
    -- Universal DELETE policy
    EXECUTE 'CREATE POLICY "allow_delete" ON ' || quote_ident(table_record.tablename) || 
            ' FOR DELETE USING (true)';
    
  END LOOP;
  RAISE NOTICE 'Created universal RLS policies on all tables';
END
$$;

-- Step 4: Ensure anon role has permissions
GRANT USAGE ON SCHEMA public TO anon;

DO $$
DECLARE
  table_record RECORD;
BEGIN
  FOR table_record IN 
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON ' || quote_ident(table_record.tablename) || ' TO anon';
  END LOOP;
END
$$;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;

-- Step 5: Verify results
SELECT 
  COUNT(*) as total_tables,
  SUM(CASE WHEN rowsecurity THEN 1 ELSE 0 END) as rls_enabled_count
FROM pg_tables 
WHERE schemaname = 'public';

-- Show sample of policies created
SELECT 
  tablename,
  COUNT(*) as policy_count,
  array_agg(policyname) as policies
FROM pg_policies 
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename
LIMIT 10;
