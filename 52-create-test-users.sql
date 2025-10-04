-- Quick User Creation for Testing
-- This will create some test users so you can see them in the assignment view

-- First, let's see what we have
SELECT 'Current users:' as info, COUNT(*) as count FROM users;

-- Create a test user if none exist
DO $$
BEGIN
    -- Only create if no users exist
    IF NOT EXISTS (SELECT 1 FROM users LIMIT 1) THEN
        -- Insert a test user
        INSERT INTO users (
            username,
            email,
            role_type,
            status,
            created_at,
            updated_at
        ) VALUES (
            'testuser',
            'test@example.com',
            'Employee',
            'active',
            NOW(),
            NOW()
        );
        
        INSERT INTO users (
            username,
            email,
            role_type,
            status,
            created_at,
            updated_at
        ) VALUES (
            'manager',
            'manager@example.com',
            'Manager',
            'active',
            NOW(),
            NOW()
        );
        
        RAISE NOTICE 'Test users created successfully!';
    ELSE
        RAISE NOTICE 'Users already exist, skipping creation.';
    END IF;
END $$;

-- Test the function to see if it returns users now
SELECT 'Testing function after user creation:' as info;
SELECT * FROM get_users_with_employee_details() LIMIT 5;

-- Simple user count check
SELECT 
    'Total active users:' as info, 
    COUNT(*) as count 
FROM users 
WHERE deleted_at IS NULL 
  AND status = 'active';