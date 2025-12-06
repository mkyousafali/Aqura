-- NUCLEAR OPTION: Remove ALL policies and recreate only permissive ones
-- This fixes the issue where multiple overlapping policies might conflict

-- 1. Drop ALL policies on receiving_records
DO $$
DECLARE 
  policy_name text;
BEGIN
  FOR policy_name IN 
    SELECT policyname FROM pg_policies WHERE tablename = 'receiving_records'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON receiving_records', policy_name);
  END LOOP;
END
$$;

-- 2. Drop ALL policies on vendor_payment_schedule
DO $$
DECLARE 
  policy_name text;
BEGIN
  FOR policy_name IN 
    SELECT policyname FROM pg_policies WHERE tablename = 'vendor_payment_schedule'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON vendor_payment_schedule', policy_name);
  END LOOP;
END
$$;

-- 3. Drop ALL policies on vendors
DO $$
DECLARE 
  policy_name text;
BEGIN
  FOR policy_name IN 
    SELECT policyname FROM pg_policies WHERE tablename = 'vendors'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON vendors', policy_name);
  END LOOP;
END
$$;

-- 4. Drop ALL policies on branches
DO $$
DECLARE 
  policy_name text;
BEGIN
  FOR policy_name IN 
    SELECT policyname FROM pg_policies WHERE tablename = 'branches'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON branches', policy_name);
  END LOOP;
END
$$;

-- Now create ONLY PERMISSIVE policies (no restrictive ones that might conflict)
CREATE POLICY "allow_all_insert" ON receiving_records FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_all_select" ON receiving_records FOR SELECT USING (true);
CREATE POLICY "allow_all_update" ON receiving_records FOR UPDATE WITH CHECK (true);
CREATE POLICY "allow_all_delete" ON receiving_records FOR DELETE USING (true);

CREATE POLICY "allow_all_insert" ON vendor_payment_schedule FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_all_select" ON vendor_payment_schedule FOR SELECT USING (true);
CREATE POLICY "allow_all_update" ON vendor_payment_schedule FOR UPDATE WITH CHECK (true);
CREATE POLICY "allow_all_delete" ON vendor_payment_schedule FOR DELETE USING (true);

CREATE POLICY "allow_all_insert" ON vendors FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_all_select" ON vendors FOR SELECT USING (true);
CREATE POLICY "allow_all_update" ON vendors FOR UPDATE WITH CHECK (true);
CREATE POLICY "allow_all_delete" ON vendors FOR DELETE USING (true);

CREATE POLICY "allow_all_insert" ON branches FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_all_select" ON branches FOR SELECT USING (true);
CREATE POLICY "allow_all_update" ON branches FOR UPDATE WITH CHECK (true);
CREATE POLICY "allow_all_delete" ON branches FOR DELETE USING (true);

-- Verify
SELECT 
  tablename,
  COUNT(*) as policy_count
FROM pg_policies 
WHERE tablename IN ('receiving_records', 'vendor_payment_schedule', 'vendors', 'branches')
GROUP BY tablename
ORDER BY tablename;
