-- =====================================================
-- Fix Fine Payment Missing Column Issue
-- Add missing fine_payment_note column and related fields
-- =====================================================

-- Add missing columns for fine payment processing
ALTER TABLE employee_warnings 
ADD COLUMN IF NOT EXISTS fine_payment_note text NULL;

ALTER TABLE employee_warnings 
ADD COLUMN IF NOT EXISTS fine_payment_method varchar(50) NULL DEFAULT 'cash';

ALTER TABLE employee_warnings 
ADD COLUMN IF NOT EXISTS fine_payment_reference varchar(100) NULL;

-- Add comments for the new columns
COMMENT ON COLUMN employee_warnings.fine_payment_note IS 'Optional note about the fine payment';
COMMENT ON COLUMN employee_warnings.fine_payment_method IS 'Method used to pay the fine (cash, bank_transfer, check, etc.)';
COMMENT ON COLUMN employee_warnings.fine_payment_reference IS 'Reference number or receipt number for the payment';

-- Update the sync trigger to handle new payment fields
CREATE OR REPLACE FUNCTION sync_fine_paid_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- Sync fine_paid_at with fine_paid_date
    NEW.fine_paid_at = NEW.fine_paid_date;
    
    -- Also sync the other way if someone updates fine_paid_at
    IF NEW.fine_paid_at IS NOT NULL AND NEW.fine_paid_date IS NULL THEN
        NEW.fine_paid_date = NEW.fine_paid_at;
    END IF;
    
    -- Set payment method to cash if not specified and fine is paid
    IF NEW.fine_status = 'paid' AND NEW.fine_payment_method IS NULL THEN
        NEW.fine_payment_method = 'cash';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Verify the new columns were added
SELECT 
    'FINE PAYMENT COLUMNS' as status,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'employee_warnings' 
  AND column_name IN ('fine_payment_note', 'fine_payment_method', 'fine_payment_reference', 'fine_paid_at', 'fine_paid_date')
ORDER BY column_name;

-- Test update to verify the columns work
/*
UPDATE employee_warnings 
SET 
    fine_payment_note = 'Test payment note',
    fine_payment_method = 'bank_transfer',
    fine_payment_reference = 'REF001'
WHERE fine_status = 'paid' 
LIMIT 1;
*/

-- Show current fine-related warnings for testing
SELECT 
    id,
    username,
    fine_amount,
    fine_status,
    fine_payment_note,
    fine_payment_method,
    fine_payment_reference,
    fine_paid_date,
    fine_paid_at
FROM employee_warnings 
WHERE has_fine = true
ORDER BY issued_at DESC;

SELECT 'FINE PAYMENT COLUMNS ADDED' as status, 'Frontend should now work without column errors' as message;