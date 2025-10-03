-- =====================================================
-- Check Warning Status vs Fine Status
-- Debug why active warnings count is incorrect
-- =====================================================

-- Check the actual warning_status of warnings with fines
SELECT 
    'WARNING STATUS CHECK' as section,
    id,
    username,
    warning_status,
    fine_status,
    has_fine,
    fine_amount,
    fine_paid_amount,
    issued_at
FROM employee_warnings 
WHERE has_fine = true 
ORDER BY issued_at DESC;

-- Check what statuses exist in the system
SELECT 
    'ALL WARNING STATUSES' as section,
    warning_status,
    COUNT(*) as count,
    COUNT(CASE WHEN has_fine = true THEN 1 END) as with_fines,
    COUNT(CASE WHEN has_fine = true AND fine_status = 'paid' THEN 1 END) as with_paid_fines
FROM employee_warnings 
WHERE is_deleted = false
GROUP BY warning_status
ORDER BY count DESC;

-- Recommended fix: Update warning_status to 'resolved' when fine is paid
-- This query shows what should be updated:
SELECT 
    'SHOULD BE RESOLVED' as section,
    id,
    username,
    warning_status,
    fine_status,
    'Should update warning_status to resolved' as action
FROM employee_warnings 
WHERE has_fine = true 
  AND fine_status = 'paid' 
  AND warning_status != 'resolved'
  AND is_deleted = false;