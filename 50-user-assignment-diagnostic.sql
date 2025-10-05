-- Diagnostic Script for User Assignment Issue
-- This will help us understand why no users are showing up

-- 1. Check if we have any users in the users table
SELECT 'Total users in database:' as info, COUNT(*) as count
FROM users;

-- 2. Check users with their basic info
SELECT 
    id,
    username,
    email,
    role_type,
    status,
    employee_id,
    deleted_at,
    created_at
FROM users 
ORDER BY created_at DESC
LIMIT 10;

-- 3. Check if users have employee_id linked
SELECT 
    'Users with employee_id:' as info,
    COUNT(*) as count
FROM users 
WHERE employee_id IS NOT NULL;

-- 4. Check if we have employees in hr_employees table
SELECT 'Total employees in hr_employees:' as info, COUNT(*) as count
FROM hr_employees;

-- 5. Test the get_users_with_employee_details function directly
SELECT * FROM get_users_with_employee_details()
LIMIT 5;

-- 6. Check for deleted users (common issue)
SELECT 
    'Active users (not deleted):' as info,
    COUNT(*) as count
FROM users 
WHERE deleted_at IS NULL;

-- 7. Check user status values
SELECT 
    status,
    COUNT(*) as count
FROM users 
GROUP BY status;

-- 8. Simple test - get users without joins
SELECT 
    id,
    username,
    email,
    role_type,
    CASE 
        WHEN deleted_at IS NULL THEN 'active'
        ELSE 'deleted'
    END as status
FROM users
WHERE deleted_at IS NULL
ORDER BY created_at DESC
LIMIT 5;