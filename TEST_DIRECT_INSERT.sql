-- ============================================================================
-- DIRECT INSERT TEST - Bypass Supabase REST API
-- ============================================================================
-- If this works, the problem is in Supabase REST API, not RLS
-- ============================================================================

-- Create a test record directly in the database
INSERT INTO receiving_records (
  user_id,
  branch_id,
  vendor_id,
  bill_date,
  bill_amount
) VALUES (
  '550e8400-e29b-41d4-a716-446655440001'::uuid,
  1,
  1,
  CURRENT_DATE,
  1000.00
);

-- Verify it was inserted
SELECT COUNT(*) as receiving_records_count FROM receiving_records;

-- Check the latest record
SELECT 
  id,
  user_id,
  branch_id,
  vendor_id,
  bill_amount,
  created_at
FROM receiving_records
ORDER BY created_at DESC
LIMIT 1;

-- ============================================================================
-- If this INSERT succeeds:
-- -> The database is fine, RLS is fine
-- -> Problem is in Supabase REST API or your application code
--
-- Possible causes:
-- 1. Supabase account has REST API disabled
-- 2. Column permissions issue
-- 3. Foreign key constraint violation
-- 4. Something in the SELECT query after INSERT is failing
-- ============================================================================
