-- List all tables to find API key storage
SELECT schemaname, tablename 
FROM pg_tables 
WHERE schemaname = 'public'
AND (tablename LIKE '%api%' OR tablename LIKE '%key%')
ORDER BY tablename;

-- List all public tables
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;
