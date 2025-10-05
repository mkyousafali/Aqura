-- Check the actual structure of the users table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'users'
ORDER BY ordinal_position;

-- Also check notifications table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'notifications'
ORDER BY ordinal_position;