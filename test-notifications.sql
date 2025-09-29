-- Quick query to test if our data is actually in Supabase
-- Run this in Supabase SQL Editor to verify the data exists

SELECT 
    title,
    type,
    priority,
    created_at,
    created_by_name
FROM notifications 
ORDER BY created_at DESC;