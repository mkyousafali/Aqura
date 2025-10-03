-- =====================================================
-- Check Fine Status in Database
-- Troubleshoot dashboard showing active fines incorrectly
-- =====================================================

-- Check all warnings with fines and their current status
SELECT 
    'ALL FINES' as section,
    id,
    username,
    fine_amount,
    fine_status,
    fine_paid_amount,
    fine_paid_at,
    fine_payment_note,
    issued_at,
    updated_at
FROM employee_warnings 
WHERE has_fine = true 
ORDER BY issued_at DESC;

-- Check what should be considered "active" fines (unpaid)
SELECT 
    'ACTIVE FINES (Should show in dashboard)' as section,
    id,
    username,
    fine_amount,
    fine_status,
    fine_paid_amount,
    fine_paid_at,
    issued_at
FROM employee_warnings 
WHERE has_fine = true 
  AND is_deleted = false 
  AND fine_status != 'paid'
ORDER BY issued_at DESC;

-- Check paid fines (should NOT show in dashboard)
SELECT 
    'PAID FINES (Should NOT show in dashboard)' as section,
    id,
    username,
    fine_amount,
    fine_status,
    fine_paid_amount,
    fine_paid_at,
    fine_payment_note,
    issued_at
FROM employee_warnings 
WHERE has_fine = true 
  AND fine_status = 'paid'
ORDER BY issued_at DESC;

-- Count summary
SELECT 
    'SUMMARY' as section,
    COUNT(*) as total_fines,
    COUNT(CASE WHEN fine_status = 'paid' THEN 1 END) as paid_fines,
    COUNT(CASE WHEN fine_status != 'paid' OR fine_status IS NULL THEN 1 END) as unpaid_fines,
    SUM(fine_amount) as total_fine_amount,
    SUM(CASE WHEN fine_status = 'paid' THEN fine_paid_amount ELSE 0 END) as total_paid_amount
FROM employee_warnings 
WHERE has_fine = true AND is_deleted = false;