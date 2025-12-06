-- ============================================================================
-- CHECK TRIGGER FUNCTIONS
-- ============================================================================

-- Get the source code of the trigger functions
SELECT 
  routine_name,
  routine_type,
  routine_definition
FROM information_schema.routines
WHERE routine_name IN ('calculate_receiving_amounts', 'auto_create_payment_schedule')
ORDER BY routine_name;

-- ============================================================================
-- These functions might be:
-- 1. Referencing tables that need additional permissions
-- 2. Trying to insert/update data in other tables
-- 3. Using features that require special permissions
-- ============================================================================
