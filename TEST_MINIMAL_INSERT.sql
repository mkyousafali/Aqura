-- ============================================================================
-- MINIMAL INSERT TEST - Only required columns
-- ============================================================================
-- Test with ONLY the 5 required columns to see if the issue is:
-- 1. A specific column that doesn't have permission
-- 2. The REST API itself
-- ============================================================================

-- Insert with minimal data (only NOT NULL columns)
INSERT INTO receiving_records (
  user_id,
  branch_id,
  vendor_id,
  bill_date,
  bill_amount
) VALUES (
  'b658eca1-3cc1-48b2-bd3c-33b81fab5a0f'::uuid,
  1,
  1617,
  '2025-12-07'::date,
  100
);

-- Verify
SELECT COUNT(*) as total FROM receiving_records;
SELECT 
  id,
  user_id,
  branch_id,
  vendor_id,
  bill_date,
  bill_amount,
  created_at
FROM receiving_records
ORDER BY created_at DESC
LIMIT 1;

-- ============================================================================
-- If this works:
-- -> Problem is with one of the optional columns in the SELECT statement
-- -> The REST API is requesting columns you don't have permission to
--
-- If this fails:
-- -> Problem is deeper - might be Supabase account-level restriction
-- ============================================================================
