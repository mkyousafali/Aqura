-- Check what user_type enum values exist
SELECT 
    e.enumlabel as enum_value
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
WHERE t.typname = 'user_type_enum'
ORDER BY e.enumsortorder;

-- Check actual user_type values in users table
SELECT DISTINCT user_type 
FROM users 
ORDER BY user_type;

-- Check users table structure
SELECT column_name, data_type, udt_name
FROM information_schema.columns
WHERE table_name = 'users' 
AND column_name LIKE '%type%' OR column_name LIKE '%role%';
