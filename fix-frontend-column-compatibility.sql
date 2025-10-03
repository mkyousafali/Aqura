-- =====================================================
-- Fix Frontend Column Compatibility Issues
-- This fixes the missing 'fine_paid_at' column error
-- =====================================================

-- Add the missing column that frontend is expecting
ALTER TABLE employee_warnings 
ADD COLUMN IF NOT EXISTS fine_paid_at timestamp without time zone NULL;

-- Update the column comment
COMMENT ON COLUMN employee_warnings.fine_paid_at IS 'Timestamp when fine was paid (same as fine_paid_date but different name for frontend compatibility)';

-- Create a trigger to sync fine_paid_date and fine_paid_at
CREATE OR REPLACE FUNCTION sync_fine_paid_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- Sync fine_paid_at with fine_paid_date
    NEW.fine_paid_at = NEW.fine_paid_date;
    
    -- Also sync the other way if someone updates fine_paid_at
    IF NEW.fine_paid_at IS NOT NULL AND NEW.fine_paid_date IS NULL THEN
        NEW.fine_paid_date = NEW.fine_paid_at;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to keep columns in sync
CREATE TRIGGER trigger_sync_fine_paid_columns
    BEFORE INSERT OR UPDATE ON employee_warnings 
    FOR EACH ROW 
    EXECUTE FUNCTION sync_fine_paid_columns();

-- Update any existing records to sync the columns
UPDATE employee_warnings 
SET fine_paid_at = fine_paid_date 
WHERE fine_paid_date IS NOT NULL AND fine_paid_at IS NULL;

-- Verify the column was added
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'employee_warnings' 
  AND column_name IN ('fine_paid_date', 'fine_paid_at')
ORDER BY column_name;

-- Show that the sync trigger was created
SELECT 
    trigger_name,
    event_manipulation,
    action_timing
FROM information_schema.triggers 
WHERE event_object_table = 'employee_warnings'
  AND trigger_name = 'trigger_sync_fine_paid_columns';

-- Script completed: Frontend column compatibility fixed