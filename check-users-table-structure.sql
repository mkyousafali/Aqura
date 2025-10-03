-- =====================================================
-- Check Users Table Structure
-- Find the correct column names for user information
-- =====================================================

-- Check the structure of the users table
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;

-- Sample a few users to see what data is available
SELECT * FROM users LIMIT 3;