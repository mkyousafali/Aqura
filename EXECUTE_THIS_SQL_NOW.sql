-- EXECUTE THIS IN SUPABASE SQL EDITOR NOW
-- Go to: https://app.supabase.com/project/urbanaqura/sql/new
-- Copy and paste this entire script, then click RUN

-- Clear all conflicting policies and recreate with only permissive ones
-- This solves the 401 "permission denied for table receiving_records" error

-- Step 1: Remove ALL existing policies from these tables
DO $$
DECLARE 
  policy_name text;
BEGIN
  FOR policy_name IN 
    SELECT policyname FROM pg_policies WHERE tablename = 'receiving_records'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON receiving_records', policy_name);
  END LOOP;
  RAISE NOTICE 'Dropped all policies on receiving_records';
END
$$;

DO $$
DECLARE 
  policy_name text;
BEGIN
  FOR policy_name IN 
    SELECT policyname FROM pg_policies WHERE tablename = 'vendor_payment_schedule'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON vendor_payment_schedule', policy_name);
  END LOOP;
  RAISE NOTICE 'Dropped all policies on vendor_payment_schedule';
END
$$;

DO $$
DECLARE 
  policy_name text;
BEGIN
  FOR policy_name IN 
    SELECT policyname FROM pg_policies WHERE tablename = 'vendors'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON vendors', policy_name);
  END LOOP;
  RAISE NOTICE 'Dropped all policies on vendors';
END
$$;

DO $$
DECLARE 
  policy_name text;
BEGIN
  FOR policy_name IN 
    SELECT policyname FROM pg_policies WHERE tablename = 'branches'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON branches', policy_name);
  END LOOP;
  RAISE NOTICE 'Dropped all policies on branches';
END
$$;

-- Step 2: Create fresh, simple permissive policies
CREATE POLICY "rls_insert" ON receiving_records FOR INSERT WITH CHECK (true);
CREATE POLICY "rls_select" ON receiving_records FOR SELECT USING (true);
CREATE POLICY "rls_update" ON receiving_records FOR UPDATE WITH CHECK (true);
CREATE POLICY "rls_delete" ON receiving_records FOR DELETE USING (true);

CREATE POLICY "rls_insert" ON vendor_payment_schedule FOR INSERT WITH CHECK (true);
CREATE POLICY "rls_select" ON vendor_payment_schedule FOR SELECT USING (true);
CREATE POLICY "rls_update" ON vendor_payment_schedule FOR UPDATE WITH CHECK (true);
CREATE POLICY "rls_delete" ON vendor_payment_schedule FOR DELETE USING (true);

CREATE POLICY "rls_insert" ON vendors FOR INSERT WITH CHECK (true);
CREATE POLICY "rls_select" ON vendors FOR SELECT USING (true);
CREATE POLICY "rls_update" ON vendors FOR UPDATE WITH CHECK (true);
CREATE POLICY "rls_delete" ON vendors FOR DELETE USING (true);

CREATE POLICY "rls_insert" ON branches FOR INSERT WITH CHECK (true);
CREATE POLICY "rls_select" ON branches FOR SELECT USING (true);
CREATE POLICY "rls_update" ON branches FOR UPDATE WITH CHECK (true);
CREATE POLICY "rls_delete" ON branches FOR DELETE USING (true);

-- Step 3: Verify the policies were created
SELECT 
  tablename,
  COUNT(*) as policy_count,
  array_agg(policyname ORDER BY policyname) as policies
FROM pg_policies 
WHERE tablename IN ('receiving_records', 'vendor_payment_schedule', 'vendors', 'branches')
GROUP BY tablename
ORDER BY tablename;
