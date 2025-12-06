-- Grant explicit INSERT permissions to anon role on all tables
-- This ensures the REST API and RPC functions can insert/update/delete

GRANT USAGE ON SCHEMA public TO anon;

-- Grant permissions on ALL tables to anon role
DO $$
DECLARE
  table_record RECORD;
BEGIN
  FOR table_record IN 
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON ' || quote_ident(table_record.tablename) || ' TO anon';
  END LOOP;
END
$$;

-- Also grant permissions on sequences (for auto-increment IDs)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;

-- Verify permissions
SELECT 
  table_name,
  grantee,
  string_agg(privilege_type, ', ' ORDER BY privilege_type) as permissions
FROM information_schema.table_privileges 
WHERE table_schema = 'public'
  AND grantee = 'anon'
GROUP BY table_name, grantee
ORDER BY table_name
LIMIT 10;
