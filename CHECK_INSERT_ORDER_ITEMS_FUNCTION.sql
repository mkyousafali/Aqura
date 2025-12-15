-- Check if insert_order_items function exists
SELECT EXISTS (
  SELECT 1 FROM information_schema.routines 
  WHERE routine_name = 'insert_order_items'
  AND routine_schema = 'public'
) as function_exists;

-- List all functions in public schema
SELECT 
  routine_name,
  routine_type,
  data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
ORDER BY routine_name;
