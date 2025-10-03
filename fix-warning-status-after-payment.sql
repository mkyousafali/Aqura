-- =====================================================
-- Fix Warning Status When Fine is Paid
-- Update warning_status to 'resolved' when fine_status is 'paid'
-- =====================================================

-- First, check current status
SELECT 
    'BEFORE UPDATE' as status,
    id,
    username,
    warning_status,
    fine_status,
    fine_paid_at
FROM employee_warnings 
WHERE has_fine = true 
  AND fine_status = 'paid' 
  AND warning_status != 'resolved'
  AND is_deleted = false;

-- Update warning_status to 'resolved' for paid fines
UPDATE employee_warnings 
SET 
    warning_status = 'resolved',
    updated_at = NOW()
WHERE has_fine = true 
  AND fine_status = 'paid' 
  AND warning_status != 'resolved'
  AND is_deleted = false;

-- Verify the update
SELECT 
    'AFTER UPDATE' as status,
    id,
    username,
    warning_status,
    fine_status,
    fine_paid_at,
    updated_at
FROM employee_warnings 
WHERE has_fine = true 
  AND fine_status = 'paid'
  AND is_deleted = false;

-- Show summary of all warning statuses
SELECT 
    'FINAL SUMMARY' as section,
    warning_status,
    COUNT(*) as count
FROM employee_warnings 
WHERE is_deleted = false
GROUP BY warning_status
ORDER BY count DESC;