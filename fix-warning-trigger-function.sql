-- Fix the sync_fine_paid_columns function to use correct field names
-- The function was referencing fine_payment_status which doesn't exist in employee_warnings table

-- Drop and recreate the function with correct field references
DROP FUNCTION IF EXISTS sync_fine_paid_columns() CASCADE;

CREATE OR REPLACE FUNCTION sync_fine_paid_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- Update fine_paid_date and fine_paid_at based on fine_status
    IF NEW.fine_status = 'paid' THEN
        NEW.fine_paid_date = COALESCE(NEW.fine_paid_date, CURRENT_TIMESTAMP::date);
        NEW.fine_paid_at = COALESCE(NEW.fine_paid_at, CURRENT_TIMESTAMP);
    ELSIF NEW.fine_status IN ('pending', 'cancelled', 'waived') THEN
        -- Clear paid date/time if status changes from paid to something else
        IF OLD.fine_status = 'paid' AND NEW.fine_status != 'paid' THEN
            NEW.fine_paid_date = NULL;
            NEW.fine_paid_at = NULL;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
DROP TRIGGER IF EXISTS trigger_sync_fine_paid_columns ON employee_warnings;

CREATE TRIGGER trigger_sync_fine_paid_columns 
    BEFORE INSERT OR UPDATE ON employee_warnings 
    FOR EACH ROW
    EXECUTE FUNCTION sync_fine_paid_columns();

-- Test the function works
SELECT 'Function sync_fine_paid_columns recreated successfully' as status;