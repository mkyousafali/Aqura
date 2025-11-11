-- ============================================================
-- TEST THE FIX
-- Run this AFTER applying the fix above
-- ============================================================

-- Test with the two receiving records that were failing:

-- Test 1: First receiving record
SELECT 
  'Test 1: Record 7cfa516e-4974-40b0-91db-a2c74783e532' as test_name,
  check_accountant_dependency('7cfa516e-4974-40b0-91db-a2c74783e532') as result;

-- Test 2: Second receiving record  
SELECT 
  'Test 2: Record 79913f8f-ca82-4482-8c22-5a84ac06f0a0' as test_name,
  check_accountant_dependency('79913f8f-ca82-4482-8c22-5a84ac06f0a0') as result;

-- ============================================================
-- EXPECTED RESULTS:
-- Both should return: { "can_complete": true, ... }
-- Since both records have pr_excel_file_uploaded = true 
-- and original_bill_uploaded = true
-- ============================================================

-- Verify the file upload status for both records:
SELECT 
  id,
  erp_purchase_invoice_reference as erp_ref,
  pr_excel_file_uploaded,
  pr_excel_file_url IS NOT NULL as has_pr_url,
  original_bill_uploaded,
  original_bill_url IS NOT NULL as has_bill_url,
  CASE 
    WHEN pr_excel_file_uploaded AND original_bill_uploaded THEN '✅ Should Allow'
    ELSE '❌ Should Block'
  END as accountant_status
FROM receiving_records
WHERE id IN (
  '7cfa516e-4974-40b0-91db-a2c74783e532',
  '79913f8f-ca82-4482-8c22-5a84ac06f0a0'
);
