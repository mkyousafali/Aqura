-- Run this ENTIRE block in Supabase SQL Editor
-- This will drop ALL versions of create_user and update_user functions

DO $$ 
DECLARE 
  func_name text;
BEGIN
  -- Loop through all create_user and update_user functions
  FOR func_name IN 
    SELECT oid::regprocedure::text 
    FROM pg_proc 
    WHERE proname IN ('create_user', 'update_user') 
      AND pg_function_is_visible(oid)
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || func_name || ' CASCADE';
    RAISE NOTICE 'Dropped: %', func_name;
  END LOOP;
END $$;
