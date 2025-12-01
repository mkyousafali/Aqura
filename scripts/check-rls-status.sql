-- Query to check RLS status for all tables in public schema
-- Run this in Supabase SQL Editor

SELECT 
    t.tablename,
    t.rowsecurity as rls_enabled,
    COUNT(p.policyname) as policy_count,
    STRING_AGG(p.policyname, ', ') as policy_names
FROM 
    pg_tables t
LEFT JOIN 
    pg_policies p ON t.tablename = p.tablename AND t.schemaname = p.schemaname
WHERE 
    t.schemaname = 'public'
    AND t.tablename NOT LIKE 'pg_%'
    AND t.tablename NOT LIKE 'sql_%'
GROUP BY 
    t.tablename, t.rowsecurity
ORDER BY 
    t.rowsecurity DESC, t.tablename;

-- Summary Statistics
SELECT 
    COUNT(*) as total_tables,
    SUM(CASE WHEN rowsecurity THEN 1 ELSE 0 END) as tables_with_rls,
    SUM(CASE WHEN NOT rowsecurity THEN 1 ELSE 0 END) as tables_without_rls,
    ROUND(100.0 * SUM(CASE WHEN rowsecurity THEN 1 ELSE 0 END) / COUNT(*), 2) as percentage_with_rls
FROM 
    pg_tables
WHERE 
    schemaname = 'public'
    AND tablename NOT LIKE 'pg_%'
    AND tablename NOT LIKE 'sql_%';
