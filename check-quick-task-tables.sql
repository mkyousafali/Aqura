-- Check if Quick Task tables exist in Supabase
-- Run this in Supabase SQL Editor to see current status

-- Check for all Quick Task related tables
SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name LIKE '%quick_task%'
ORDER BY table_name;

-- Check for storage bucket
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets 
WHERE id = 'quick-task-files';

-- Check storage policies (if bucket exists)
SELECT policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE schemaname = 'storage' 
AND tablename = 'objects'
AND policyname LIKE '%quick task%';

-- If tables exist, check sample data
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'quick_tasks') THEN
        RAISE NOTICE 'quick_tasks table EXISTS - Row count: %', (SELECT COUNT(*) FROM quick_tasks);
    ELSE
        RAISE NOTICE 'quick_tasks table DOES NOT EXIST';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'quick_task_user_preferences') THEN
        RAISE NOTICE 'quick_task_user_preferences table EXISTS - Row count: %', (SELECT COUNT(*) FROM quick_task_user_preferences);
    ELSE
        RAISE NOTICE 'quick_task_user_preferences table DOES NOT EXIST';
    END IF;
END $$;