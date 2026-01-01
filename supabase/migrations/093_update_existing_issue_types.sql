-- Update existing purchase voucher items to set issue_type to 'not issued'
UPDATE purchase_voucher_items
SET issue_type = 'not issued';

-- Add a default value to the issue_type column if it doesn't have one
ALTER TABLE purchase_voucher_items
ALTER COLUMN issue_type SET DEFAULT 'not issued';
