-- =====================================================
-- Fix Duplicate Warning Save Issue - Final Solution
-- Remove restrictive constraint and fix frontend logic
-- =====================================================

-- 1. Remove the problematic unique constraint
DROP INDEX IF EXISTS idx_employee_warnings_unique_hourly;
DROP INDEX IF EXISTS idx_employee_warnings_unique_content;
DROP INDEX IF EXISTS idx_employee_warnings_unique_daily;

-- 2. Add a simple flag-based duplicate prevention
-- Add a column to track if warning was already saved from frontend
ALTER TABLE employee_warnings 
ADD COLUMN IF NOT EXISTS frontend_save_id varchar(50) NULL;

-- 3. Create a more reasonable unique constraint on reference number only
-- (Warning reference numbers should be unique)
CREATE UNIQUE INDEX IF NOT EXISTS idx_employee_warnings_reference_unique
ON employee_warnings (warning_reference)
WHERE warning_reference IS NOT NULL;

-- 4. Add index for performance on common queries
CREATE INDEX IF NOT EXISTS idx_employee_warnings_user_type_date
ON employee_warnings (user_id, warning_type, issued_at);

-- 5. Check current state
SELECT 
    'Current Warnings Count' as status,
    count(*) as count
FROM employee_warnings 
WHERE is_deleted = false;

-- 6. Show indexes
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'employee_warnings'
  AND indexname LIKE '%unique%';

-- Now the frontend can save warnings without duplicate constraint errors
-- The warning_reference will be unique (auto-generated) but content can be similar

COMMENT ON COLUMN employee_warnings.frontend_save_id IS 'Optional ID from frontend to prevent duplicate saves from same session';

-- Test: Try to insert same warning - should work now
/*
INSERT INTO employee_warnings (
    user_id,
    username,
    warning_type,
    warning_text,
    issued_by,
    issued_by_username
) VALUES (
    'test-user-1',
    'test_user',
    'overall_performance_with_fine',
    'Test warning text',
    'admin-user',
    'admin'
);

-- This should insert successfully (no duplicate constraint error)
*/