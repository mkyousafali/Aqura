-- Check if ai_api_keys table exists and its schema
SELECT schemaname, tablename 
FROM pg_tables 
WHERE tablename = 'ai_api_keys';

-- Check RLS status
SELECT schemaname, tablename, rowsecurity
FROM pg_tables 
WHERE tablename = 'ai_api_keys';

-- List all RLS policies on ai_api_keys
SELECT schemaname, tablename, policyname, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'ai_api_keys';

-- Check table columns
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'ai_api_keys'
ORDER BY ordinal_position;

-- Check table grants/permissions
SELECT grantee, privilege_type
FROM info_schema.role_table_grants 
WHERE table_name = 'ai_api_keys';
