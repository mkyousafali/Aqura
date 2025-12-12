-- Check if button tables are in correct schema and check for triggers

-- Verify table schema location
SELECT 
  schemaname,
  tablename
FROM pg_tables
WHERE tablename LIKE 'button_%' OR tablename = 'branches';

-- Check for any triggers that might block INSERT
SELECT 
  trigger_schema,
  trigger_name,
  event_manipulation,
  event_object_table
FROM information_schema.triggers
WHERE event_object_table LIKE 'button_%';

-- Check table constraints
SELECT 
  constraint_name,
  constraint_type,
  table_name
FROM information_schema.table_constraints
WHERE table_name LIKE 'button_%'
ORDER BY table_name;

-- Check if button tables are in public schema
SELECT 
  nspname as schema,
  relname as table_name,
  relkind
FROM pg_class
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE relname LIKE 'button_%'
ORDER BY nspname, relname;
