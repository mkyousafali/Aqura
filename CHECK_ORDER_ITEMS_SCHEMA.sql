-- Check order_items table structure
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'order_items'
ORDER BY ordinal_position;

-- Also check if bundle_id column exists
SELECT EXISTS (
  SELECT 1 FROM information_schema.columns 
  WHERE table_name = 'order_items' AND column_name = 'bundle_id'
) as has_bundle_id;

-- Check if created_at column exists
SELECT EXISTS (
  SELECT 1 FROM information_schema.columns 
  WHERE table_name = 'order_items' AND column_name = 'created_at'
) as has_created_at;
