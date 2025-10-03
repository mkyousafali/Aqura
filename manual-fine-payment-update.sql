-- =====================================================
-- Manual Fine Payment Update
-- Use this if the payment didn't save properly
-- =====================================================

-- First, check the current status of recent fines
SELECT id, username, fine_status, fine_amount, fine_paid_amount, fine_paid_at 
FROM employee_warnings 
WHERE has_fine = true 
ORDER BY issued_at DESC 
LIMIT 5;

-- If you see a fine that should be paid but shows as unpaid, 
-- update it manually (replace the ID with the actual warning ID):

/*
UPDATE employee_warnings 
SET 
    fine_status = 'paid',
    fine_paid_amount = 100.00,  -- Replace with actual amount
    fine_paid_at = NOW(),
    fine_payment_note = 'Manual payment entry',
    updated_at = NOW()
WHERE id = 'YOUR_WARNING_ID_HERE';  -- Replace with actual ID
*/

-- Verify the update worked
SELECT id, username, fine_status, fine_amount, fine_paid_amount, fine_paid_at 
FROM employee_warnings 
WHERE has_fine = true 
ORDER BY issued_at DESC 
LIMIT 5;