-- Query to compare branches vs button_main_sections structure

-- Check branches columns and constraints
SELECT 
  'branches' as table_name,
  column_name,
  data_type,
  is_nullable,
  column_default,
  ordinal_position
FROM information_schema.columns 
WHERE table_name = 'branches'
ORDER BY ordinal_position;

-- Check button_main_sections columns and constraints
SELECT 
  'button_main_sections' as table_name,
  column_name,
  data_type,
  is_nullable,
  column_default,
  ordinal_position
FROM information_schema.columns 
WHERE table_name = 'button_main_sections'
ORDER BY ordinal_position;

-- Check if there are any constraints/triggers that might block inserts
SELECT 
  tablename,
  trigname,
  tgtype
FROM pg_trigger
WHERE tablename IN ('branches', 'button_main_sections');

-- Check RLS status
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename IN ('branches', 'button_main_sections');
