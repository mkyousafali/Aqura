-- ============================================================
-- STEP 2: CHECK WHICH FUNCTIONS EXIST
-- Copy and paste this in Supabase SQL Editor  
-- ============================================================

-- List all receiving task completion functions
SELECT 
  proname as function_name,
  pg_get_function_arguments(oid) as parameters,
  pg_get_function_result(oid) as return_type
FROM pg_proc 
WHERE proname LIKE '%complete_receiving_task%'
AND pronamespace = 'public'::regnamespace
ORDER BY proname;

-- ============================================================
-- This will show you all the complete_receiving_task functions
-- ============================================================
