-- =====================================================
-- Clean Warning Tables Data - Complete Reset
-- This script removes all data from warning tables for fresh start
-- =====================================================

-- Step 1: Check current data before cleanup
SELECT 
    'BEFORE CLEANUP' as phase,
    'employee_warnings' as table_name,
    count(*) as record_count
FROM employee_warnings
UNION ALL
SELECT 
    'BEFORE CLEANUP' as phase,
    'employee_warning_history' as table_name,
    count(*) as record_count
FROM employee_warning_history
ORDER BY table_name;

-- =====================================================
-- Option 1: COMPLETE DATA REMOVAL (Recommended for fresh start)
-- =====================================================

-- Disable triggers temporarily to avoid conflicts during cleanup
DROP TRIGGER IF EXISTS trigger_create_warning_history ON employee_warnings;
DROP TRIGGER IF EXISTS trigger_generate_warning_reference ON employee_warnings;
DROP TRIGGER IF EXISTS trigger_update_warning_updated_at ON employee_warnings;
DROP TRIGGER IF EXISTS trigger_sync_fine_paid_columns ON employee_warnings;

-- Delete all warning history records first (due to foreign key constraints)
DELETE FROM employee_warning_history;

-- Delete all warning records
DELETE FROM employee_warnings;

-- Reset any sequences (if they exist)
-- This ensures warning reference numbers start fresh
-- Note: PostgreSQL auto-generates UUIDs, so no sequence reset needed for IDs

-- Recreate the triggers we dropped
-- (Using the functions that should already exist)

-- Trigger for updating timestamp
CREATE TRIGGER trigger_update_warning_updated_at 
    BEFORE UPDATE ON employee_warnings 
    FOR EACH ROW 
    EXECUTE FUNCTION update_warning_updated_at();

-- Trigger for generating warning reference
CREATE TRIGGER trigger_generate_warning_reference 
    BEFORE INSERT ON employee_warnings 
    FOR EACH ROW 
    EXECUTE FUNCTION generate_warning_reference();

-- Trigger for history tracking
CREATE TRIGGER trigger_create_warning_history
    AFTER INSERT OR UPDATE OR DELETE ON employee_warnings 
    FOR EACH ROW 
    EXECUTE FUNCTION create_warning_history();

-- Trigger for syncing fine payment columns
CREATE TRIGGER trigger_sync_fine_paid_columns
    BEFORE INSERT OR UPDATE ON employee_warnings 
    FOR EACH ROW 
    EXECUTE FUNCTION sync_fine_paid_columns();

-- =====================================================
-- Option 2: SOFT DELETE (Alternative - keeps data but marks as deleted)
-- =====================================================

/*
-- Uncomment this section if you want to soft delete instead of hard delete

-- Soft delete all warnings (marks as deleted but keeps data)
UPDATE employee_warnings 
SET 
    is_deleted = true,
    deleted_at = CURRENT_TIMESTAMP,
    deleted_by = 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b'  -- Master admin ID
WHERE is_deleted = false;

-- Add history record for bulk soft delete
INSERT INTO employee_warning_history (
    warning_id,
    action_type,
    old_values,
    new_values,
    changed_by,
    changed_by_username,
    change_reason
)
SELECT 
    id,
    'deleted',
    to_jsonb(employee_warnings.*),
    NULL,
    'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b',
    'madmin',
    'Bulk cleanup - soft delete all warnings'
FROM employee_warnings 
WHERE is_deleted = true;
*/

-- =====================================================
-- Verification after cleanup
-- =====================================================

-- Check data after cleanup
SELECT 
    'AFTER CLEANUP' as phase,
    'employee_warnings' as table_name,
    count(*) as record_count
FROM employee_warnings
UNION ALL
SELECT 
    'AFTER CLEANUP' as phase,
    'employee_warning_history' as table_name,
    count(*) as record_count
FROM employee_warning_history
ORDER BY table_name;

-- Verify triggers are back in place
SELECT 
    'TRIGGERS RESTORED' as status,
    trigger_name,
    event_manipulation,
    action_timing
FROM information_schema.triggers 
WHERE event_object_table = 'employee_warnings'
ORDER BY trigger_name;

-- Check table structure is intact
SELECT 
    'TABLE STRUCTURE' as status,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'employee_warnings'
  AND column_name IN (
    'id', 'user_id', 'employee_id', 'username', 'warning_type', 
    'warning_text', 'issued_at', 'warning_reference', 'fine_paid_at'
  )
ORDER BY ordinal_position;

-- Show constraints are intact
SELECT 
    'CONSTRAINTS' as status,
    constraint_name,
    constraint_type
FROM information_schema.table_constraints 
WHERE table_name = 'employee_warnings'
ORDER BY constraint_type, constraint_name;

-- =====================================================
-- Test insert to verify system is working
-- =====================================================

/*
-- Uncomment to test with sample data
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
    'test-user-id',
    'test-employee-id',
    'test_user',
    'overall_performance_no_fine',
    'Test warning after cleanup',
    'en',
    'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b',
    'madmin',
    'active',
    'medium'
);

-- Verify test insert worked
SELECT 
    'TEST INSERT' as status,
    id,
    username,
    warning_type,
    warning_reference,
    issued_at
FROM employee_warnings
WHERE username = 'test_user';

-- Check history was created
SELECT 
    'TEST HISTORY' as status,
    action_type,
    changed_by_username,
    created_at
FROM employee_warning_history
WHERE action_type = 'created';

-- Clean up test data
-- DELETE FROM employee_warning_history WHERE action_type = 'created';
-- DELETE FROM employee_warnings WHERE username = 'test_user';
*/

-- =====================================================
-- Final status
-- =====================================================

SELECT 
    'CLEANUP COMPLETE' as status,
    'Warning tables are now clean and ready for fresh data' as message,
    CURRENT_TIMESTAMP as completed_at;

-- Summary of what was cleaned:
SELECT 
    'SUMMARY' as type,
    'All warning data removed' as action,
    'Tables reset to empty state' as result,
    'System ready for new warnings' as next_step;