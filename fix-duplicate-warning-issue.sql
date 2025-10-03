-- =====================================================
-- Fix Duplicate Warning Records Issue
-- =====================================================

-- Step 1: Check current state before cleanup
SELECT 
    'BEFORE CLEANUP - Total Warnings' as status,
    count(*) as count
FROM employee_warnings 
WHERE is_deleted = false;

-- Step 2: CLEAR ALL CURRENT WARNING DATA (as requested)
-- This will clean slate for fresh start

-- Disable only our custom triggers (not system FK triggers)
DROP TRIGGER IF EXISTS trigger_create_warning_history ON employee_warnings;
DROP TRIGGER IF EXISTS trigger_generate_warning_reference ON employee_warnings;
DROP TRIGGER IF EXISTS trigger_update_warning_updated_at ON employee_warnings;

-- Clear all warning history first (due to foreign key constraints)
DELETE FROM employee_warning_history;

-- Clear all warning records  
DELETE FROM employee_warnings;

-- Note: We'll recreate the triggers later in the script

-- Verify cleanup
SELECT 
    'AFTER CLEANUP - Total Warnings' as status,
    count(*) as count
FROM employee_warnings;

SELECT 
    'AFTER CLEANUP - Warning History' as status,
    count(*) as count
FROM employee_warning_history;

-- =====================================================
-- Check what WAS causing the duplication (for reference)
-- =====================================================

-- Check if there are multiple triggers causing duplication
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'employee_warnings'
ORDER BY trigger_name;

-- Check for any duplicate triggers or functions
SELECT 
    routine_name,
    count(*) as function_count
FROM information_schema.routines 
WHERE routine_name IN ('create_warning_history', 'generate_warning_reference', 'update_warning_updated_at')
GROUP BY routine_name;

-- =====================================================
-- Fix 1: No need to clean duplicates since we cleared everything above
-- =====================================================

-- =====================================================
-- Fix 2: Recreate triggers properly to prevent future duplicates
-- =====================================================

-- Note: Triggers were already dropped during cleanup above
-- Drop and recreate the history function with better logic
DROP FUNCTION IF EXISTS create_warning_history();

-- Updated function to prevent duplicates and handle edge cases
CREATE OR REPLACE FUNCTION create_warning_history()
RETURNS TRIGGER AS $$
DECLARE
    current_user_id uuid;
    current_username text;
BEGIN
    -- Get current user info for history tracking
    current_user_id := COALESCE(
        CASE TG_OP 
            WHEN 'INSERT' THEN NEW.issued_by
            WHEN 'UPDATE' THEN NEW.issued_by
            WHEN 'DELETE' THEN OLD.deleted_by
        END
    );
    
    current_username := COALESCE(
        CASE TG_OP 
            WHEN 'INSERT' THEN NEW.issued_by_username
            WHEN 'UPDATE' THEN NEW.issued_by_username
            WHEN 'DELETE' THEN 'system'
        END, 
        'system'
    );

    -- Handle INSERT (new warning created)
    IF TG_OP = 'INSERT' THEN
        INSERT INTO employee_warning_history (
            warning_id, 
            action_type, 
            old_values, 
            new_values, 
            changed_by, 
            changed_by_username
        )
        VALUES (
            NEW.id, 
            'created', 
            NULL, 
            to_jsonb(NEW), 
            current_user_id,
            current_username
        );
        RETURN NEW;
    END IF;
    
    -- Handle UPDATE (warning modified) - only if meaningful changes occurred
    IF TG_OP = 'UPDATE' THEN
        -- Only log if there are actual changes (excluding updated_at timestamp)
        IF (OLD.warning_status != NEW.warning_status OR 
            OLD.fine_status != NEW.fine_status OR 
            OLD.warning_text != NEW.warning_text OR
            OLD.acknowledged_at != NEW.acknowledged_at OR
            OLD.resolved_at != NEW.resolved_at) THEN
            
            INSERT INTO employee_warning_history (
                warning_id, 
                action_type, 
                old_values, 
                new_values, 
                changed_by, 
                changed_by_username
            )
            VALUES (
                NEW.id, 
                'updated', 
                to_jsonb(OLD), 
                to_jsonb(NEW), 
                current_user_id,
                current_username
            );
        END IF;
        RETURN NEW;
    END IF;
    
    -- Handle DELETE (warning deleted)
    IF TG_OP = 'DELETE' THEN
        INSERT INTO employee_warning_history (
            warning_id, 
            action_type, 
            old_values, 
            new_values, 
            changed_by, 
            changed_by_username
        )
        VALUES (
            OLD.id, 
            'deleted', 
            to_jsonb(OLD), 
            NULL, 
            current_user_id,
            current_username
        );
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Fix 3: Recreate triggers with proper timing
-- =====================================================

-- Trigger for reference number generation (BEFORE INSERT only)
CREATE TRIGGER trigger_generate_warning_reference 
    BEFORE INSERT ON employee_warnings 
    FOR EACH ROW 
    EXECUTE FUNCTION generate_warning_reference();

-- Trigger for updating timestamp (BEFORE UPDATE only)
CREATE TRIGGER trigger_update_warning_updated_at 
    BEFORE UPDATE ON employee_warnings 
    FOR EACH ROW 
    EXECUTE FUNCTION update_warning_updated_at();

-- Trigger for history tracking (AFTER operations)
CREATE TRIGGER trigger_create_warning_history
    AFTER INSERT OR UPDATE OR DELETE ON employee_warnings 
    FOR EACH ROW 
    EXECUTE FUNCTION create_warning_history();

-- =====================================================
-- Fix 4: Add constraint to prevent logical duplicates
-- =====================================================

-- Drop existing unique constraint if it exists
DROP INDEX IF EXISTS idx_employee_warnings_unique_daily;
DROP INDEX IF EXISTS idx_employee_warnings_unique_content;

-- Create a more reasonable unique index that prevents duplicates within same hour
-- (allows multiple warnings per day but prevents rapid-fire duplicates)
CREATE UNIQUE INDEX IF NOT EXISTS idx_employee_warnings_unique_hourly
ON employee_warnings (user_id, warning_type, DATE_TRUNC('hour', issued_at))
WHERE is_deleted = false;

-- This prevents duplicate warnings of same type for same user within same hour
-- but allows legitimate multiple warnings throughout the day

-- =====================================================
-- Verification after fix
-- =====================================================

-- Check remaining triggers (should be 3 triggers)
SELECT 
    trigger_name,
    event_manipulation,
    action_timing
FROM information_schema.triggers 
WHERE event_object_table = 'employee_warnings'
ORDER BY trigger_name;

-- Check for any remaining duplicates (should be none)
SELECT 
    'After Fix - Remaining Duplicates (should be 0)' as check_type,
    count(*) as total_count
FROM employee_warnings 
WHERE is_deleted = false;

-- Show functions are properly created
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_name IN ('create_warning_history', 'generate_warning_reference', 'update_warning_updated_at')
ORDER BY routine_name;

-- =====================================================
-- Fix 5: Data is already cleared above - this section shows final state
-- =====================================================

-- Final verification - should show 0 records
SELECT 
    'Final State - Active Warnings' as status,
    count(*) as count
FROM employee_warnings 
WHERE is_deleted = false;

-- Check total records (should be 0)
SELECT 
    'Final State - Total Warning Records' as status,
    count(*) as count
FROM employee_warnings;

-- Check history records (should be 0)
SELECT 
    'Final State - Warning History Records' as status,
    count(*) as count
FROM employee_warning_history;

-- =====================================================
-- Optional: Test the fix with a sample insert
-- =====================================================

/*
-- Test with actual admin ID (replace user-id and employee-id with real values)
INSERT INTO employee_warnings (
    user_id,
    employee_id,
    username,
    warning_type,
    warning_text,
    language_code,
    issued_by,
    issued_by_username,
    warning_status,
    severity_level
) VALUES (
    'user-id-here',  -- Replace with actual user ID
    'employee-id-here',  -- Replace with actual employee ID
    'test_user',
    'overall_performance_no_fine',
    'Test warning - should not duplicate',
    'en',
    'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b',  -- Master admin ID
    'madmin',
    'active',
    'medium'
);

-- Check if only one record was created
SELECT count(*) as should_be_one 
FROM employee_warnings 
WHERE username = 'test_user' AND warning_text = 'Test warning - should not duplicate';

-- Check that history was created
SELECT count(*) as history_records
FROM employee_warning_history
WHERE action_type = 'created';
*/