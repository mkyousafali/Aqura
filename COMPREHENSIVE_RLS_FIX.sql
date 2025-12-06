-- Comprehensive RLS fix for receiving_records and related tables
-- This ensures all operations are allowed

-- 1. Fix receiving_records table
DROP POLICY IF EXISTS "allow_all_operations" ON receiving_records;
DROP POLICY IF EXISTS "allow_insert_receiving" ON receiving_records;
DROP POLICY IF EXISTS "allow_select_receiving" ON receiving_records;
DROP POLICY IF EXISTS "allow_update_receiving" ON receiving_records;
DROP POLICY IF EXISTS "allow_delete_receiving" ON receiving_records;

-- Create simple permissive policies
CREATE POLICY "rls_insert" ON receiving_records FOR INSERT WITH CHECK (true);
CREATE POLICY "rls_select" ON receiving_records FOR SELECT USING (true);
CREATE POLICY "rls_update" ON receiving_records FOR UPDATE WITH CHECK (true);
CREATE POLICY "rls_delete" ON receiving_records FOR DELETE USING (true);

-- 2. Fix vendor_payment_schedule table (referenced by trigger)
DROP POLICY IF EXISTS "allow_all_operations" ON vendor_payment_schedule;
DROP POLICY IF EXISTS "rls_insert" ON vendor_payment_schedule;
DROP POLICY IF EXISTS "rls_select" ON vendor_payment_schedule;
DROP POLICY IF EXISTS "rls_update" ON vendor_payment_schedule;
DROP POLICY IF EXISTS "rls_delete" ON vendor_payment_schedule;

CREATE POLICY "rls_insert" ON vendor_payment_schedule FOR INSERT WITH CHECK (true);
CREATE POLICY "rls_select" ON vendor_payment_schedule FOR SELECT USING (true);
CREATE POLICY "rls_update" ON vendor_payment_schedule FOR UPDATE WITH CHECK (true);
CREATE POLICY "rls_delete" ON vendor_payment_schedule FOR DELETE USING (true);

-- 3. Fix vendors table (referenced by trigger)
DROP POLICY IF EXISTS "allow_all_operations" ON vendors;
DROP POLICY IF EXISTS "rls_insert" ON vendors;
DROP POLICY IF EXISTS "rls_select" ON vendors;
DROP POLICY IF EXISTS "rls_update" ON vendors;
DROP POLICY IF EXISTS "rls_delete" ON vendors;

CREATE POLICY "rls_insert" ON vendors FOR INSERT WITH CHECK (true);
CREATE POLICY "rls_select" ON vendors FOR SELECT USING (true);
CREATE POLICY "rls_update" ON vendors FOR UPDATE WITH CHECK (true);
CREATE POLICY "rls_delete" ON vendors FOR DELETE USING (true);

-- 4. Fix branches table (referenced by trigger)
DROP POLICY IF EXISTS "allow_all_operations" ON branches;
DROP POLICY IF EXISTS "rls_insert" ON branches;
DROP POLICY IF EXISTS "rls_select" ON branches;
DROP POLICY IF EXISTS "rls_update" ON branches;
DROP POLICY IF EXISTS "rls_delete" ON branches;

CREATE POLICY "rls_insert" ON branches FOR INSERT WITH CHECK (true);
CREATE POLICY "rls_select" ON branches FOR SELECT USING (true);
CREATE POLICY "rls_update" ON branches FOR UPDATE WITH CHECK (true);
CREATE POLICY "rls_delete" ON branches FOR DELETE USING (true);

-- Verify policies
SELECT 
  tablename,
  COUNT(*) as policy_count,
  array_agg(policyname ORDER BY policyname) as policies
FROM pg_policies 
WHERE tablename IN ('receiving_records', 'vendor_payment_schedule', 'vendors', 'branches')
GROUP BY tablename
ORDER BY tablename;
