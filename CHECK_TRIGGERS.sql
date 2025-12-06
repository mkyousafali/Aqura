-- ============================================================================
-- CHECK FOR TRIGGERS AND FUNCTIONS
-- ============================================================================

-- Check if there are any triggers on receiving_records
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_timing,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'receiving_records'
ORDER BY trigger_name;

-- ============================================================================
-- If there are triggers, they might be blocking the INSERT
-- Common causes:
-- 1. Trigger validation that fails
-- 2. Trigger that calls a function with permission issues
-- 3. Trigger that references tables the user can't access
-- ============================================================================
