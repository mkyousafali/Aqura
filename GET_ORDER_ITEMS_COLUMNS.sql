-- Get all columns in order_items table with their types
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default,
  ordinal_position
FROM information_schema.columns
WHERE table_name = 'order_items'
ORDER BY ordinal_position;
