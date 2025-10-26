-- Migration: Add Payment Approval Columns to Users Table
-- Description: Add columns to track user payment approval permissions and limits

-- Add payment approval columns to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS can_approve_payments BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS approval_amount_limit DECIMAL(15, 2) DEFAULT 0.00;

-- Create index for faster queries on approval-enabled users
CREATE INDEX IF NOT EXISTS idx_users_can_approve_payments ON users(can_approve_payments) WHERE can_approve_payments = true;

-- Add comments for documentation
COMMENT ON COLUMN users.can_approve_payments IS 'Flag indicating whether the user has permission to approve expense requisitions';
COMMENT ON COLUMN users.approval_amount_limit IS 'Maximum amount (in SAR) that the user can approve. 0 or NULL means no limit';

-- Update existing admin/manager users to have approval permissions (optional - adjust as needed)
-- You can uncomment and modify this based on your requirements:
/*
UPDATE users 
SET 
    can_approve_payments = true,
    approval_amount_limit = 50000.00
WHERE user_type = 'global' OR position_id IN (
    SELECT id FROM positions WHERE title ILIKE '%manager%' OR title ILIKE '%admin%'
);
*/

-- Example: Set specific approval limits based on role
/*
-- Branch managers: 10,000 SAR limit
UPDATE users SET can_approve_payments = true, approval_amount_limit = 10000.00 
WHERE position_id IN (SELECT id FROM positions WHERE title ILIKE '%branch manager%');

-- Finance team: 50,000 SAR limit
UPDATE users SET can_approve_payments = true, approval_amount_limit = 50000.00 
WHERE position_id IN (SELECT id FROM positions WHERE title ILIKE '%finance%');

-- CEO/Directors: Unlimited
UPDATE users SET can_approve_payments = true, approval_amount_limit = NULL 
WHERE position_id IN (SELECT id FROM positions WHERE title ILIKE '%director%' OR title ILIKE '%ceo%');
*/
