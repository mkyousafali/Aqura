-- Remove remarks column and add issue_remarks, close_remarks, close_bill_number

-- Drop the remarks column
ALTER TABLE purchase_voucher_items 
DROP COLUMN IF EXISTS remarks;

-- Add new columns
ALTER TABLE purchase_voucher_items 
ADD COLUMN IF NOT EXISTS issue_remarks TEXT,
ADD COLUMN IF NOT EXISTS close_remarks TEXT,
ADD COLUMN IF NOT EXISTS close_bill_number VARCHAR;

-- Add indexes for better query performance on the new columns
CREATE INDEX IF NOT EXISTS idx_pvi_close_bill_number 
ON purchase_voucher_items USING btree (close_bill_number);
