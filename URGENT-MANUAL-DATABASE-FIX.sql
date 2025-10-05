-- URGENT: Manual Database Fix for Warning System
-- This needs to be executed in Supabase SQL Editor to fix the warning system

-- Step 1: Drop the broken trigger function
DROP FUNCTION IF EXISTS sync_fine_paid_columns() CASCADE;

-- Step 2: Create the corrected function (using fine_status instead of fine_payment_status)
CREATE OR REPLACE FUNCTION sync_fine_paid_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- Update fine_paid_date and fine_paid_at based on fine_status (NOT fine_payment_status)
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

-- Step 3: Recreate the trigger
DROP TRIGGER IF EXISTS trigger_sync_fine_paid_columns ON employee_warnings;

CREATE TRIGGER trigger_sync_fine_paid_columns 
    BEFORE INSERT OR UPDATE ON employee_warnings 
    FOR EACH ROW
    EXECUTE FUNCTION sync_fine_paid_columns();

-- Step 4: Test the fix
SELECT 'Database trigger function fixed successfully' as status;

-- Verification query to check if function exists
SELECT 
    p.proname as function_name,
    pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'sync_fine_paid_columns';