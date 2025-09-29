-- Query to check the exact column names in our notifications table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'notifications' 
AND table_schema = 'public'
ORDER BY ordinal_position;