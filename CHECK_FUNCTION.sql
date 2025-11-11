-- ============================================================
-- STEP 1: CHECK CURRENT FUNCTION DEFINITION
-- Copy and paste this in Supabase SQL Editor
-- ============================================================

-- Get the complete function definition for complete_receiving_task
SELECT pg_get_functiondef(oid) as function_definition
FROM pg_proc 
WHERE proname = 'complete_receiving_task' 
AND pronamespace = 'public'::regnamespace;

-- ============================================================
-- After you run this, copy the result and paste it back to me
-- I need to see the function code to create the fix
-- ============================================================
