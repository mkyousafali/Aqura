-- =====================================================
-- Warning Tables Data Cleanup Script
-- This script provides options to clean up warning data
-- =====================================================

-- Option 1: Soft delete all warnings (recommended - keeps data for audit)
-- This sets is_deleted = true instead of actually deleting records
UPDATE employee_warnings 
SET 
    is_deleted = true,
    deleted_at = CURRENT_TIMESTAMP,
    deleted_by = 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b' -- Replace with actual admin user ID
WHERE is_deleted = false;

-- Verify soft deletion
SELECT 
    COUNT(*) as total_warnings,
    SUM(CASE WHEN is_deleted = true THEN 1 ELSE 0 END) as deleted_warnings,
    SUM(CASE WHEN is_deleted = false THEN 1 ELSE 0 END) as active_warnings
FROM employee_warnings;

-- =====================================================

-- Option 2: Complete data removal (DANGEROUS - use with caution)
-- Uncomment the lines below ONLY if you want to permanently delete all data

-- -- Delete all employee warnings
-- DELETE FROM employee_warnings;

-- -- Reset the sequence if you want to start IDs from beginning
-- -- (Note: PostgreSQL uses UUID by default, so this may not be needed)

-- -- Verify deletion
-- SELECT COUNT(*) as remaining_warnings FROM employee_warnings;

-- =====================================================

-- Option 3: Delete only specific types of warnings
-- Example: Delete only warnings without fines

-- UPDATE employee_warnings 
-- SET 
--     is_deleted = true,
--     deleted_at = CURRENT_TIMESTAMP,
--     deleted_by = 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b'
-- WHERE has_fine = false AND is_deleted = false;

-- =====================================================

-- Option 4: Delete warnings older than a certain date
-- Example: Delete warnings older than 30 days

-- UPDATE employee_warnings 
-- SET 
--     is_deleted = true,
--     deleted_at = CURRENT_TIMESTAMP,
--     deleted_by = 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b'
-- WHERE issued_at < (CURRENT_DATE - INTERVAL '30 days') 
--   AND is_deleted = false;

-- =====================================================

-- Option 5: View current warning data before cleanup
SELECT 
    id,
    username,
    warning_type,
    has_fine,
    fine_amount,
    warning_status,
    issued_at,
    is_deleted
FROM employee_warnings 
ORDER BY issued_at DESC
LIMIT 10;

-- =====================================================

-- Option 6: Backup data before cleanup (recommended)
-- Create a backup table with current data

-- CREATE TABLE employee_warnings_backup_20241002 AS 
-- SELECT * FROM employee_warnings WHERE is_deleted = false;

-- Verify backup
-- SELECT COUNT(*) as backed_up_records FROM employee_warnings_backup_20241002;

-- =====================================================

-- Option 7: Restore soft-deleted warnings (undo soft delete)
-- Uncomment to restore all soft-deleted warnings

-- UPDATE employee_warnings 
-- SET 
--     is_deleted = false,
--     deleted_at = NULL,
--     deleted_by = NULL
-- WHERE is_deleted = true;