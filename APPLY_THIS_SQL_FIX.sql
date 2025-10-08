-- Double-check that the constraints are actually removed
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'notification_queue'
    AND schemaname = 'public'
ORDER BY indexname;

-- Also check for any remaining unique constraints
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(c.oid) as constraint_definition
FROM pg_constraint c
JOIN pg_class t ON c.conrelid = t.oid
JOIN pg_namespace n ON t.relnamespace = n.oid
WHERE t.relname = 'notification_queue'
    AND n.nspname = 'public'
    AND c.contype = 'u'  -- unique constraints only
ORDER BY c.conname;