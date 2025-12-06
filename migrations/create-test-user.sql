-- Create test user for authentication testing
-- Test User: testuser
-- Quick Access Code: 123456
-- Purpose: Verify that user table stores credentials and authentication system works

-- Step 1: Create the test user in the users table
INSERT INTO users (
  username,
  email,
  password_hash,
  quick_access_code,
  role,
  role_type,
  user_type,
  status,
  created_at,
  updated_at
) VALUES (
  'testuser',
  'testuser@aqura.local',
  -- Password hash for "password123" using bcrypt (pre-generated)
  -- You can generate one using: npx bcryptjs hash password123
  '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36P4/exa',
  '123456',
  'admin',
  'ADMIN',
  'EMPLOYEE',
  'ACTIVE',
  NOW(),
  NOW()
)
ON CONFLICT (username) DO UPDATE
SET 
  quick_access_code = '123456',
  password_hash = '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36P4/exa',
  status = 'ACTIVE',
  updated_at = NOW()
RETURNING id, username, email, role_type, status;

-- Step 2: Verify the test user was created
SELECT 
  id,
  username,
  email,
  role_type,
  user_type,
  status,
  quick_access_code,
  created_at
FROM users
WHERE username = 'testuser';

-- Step 3: Check RLS policies on users table
SELECT
  schemaname,
  tablename,
  policyname,
  qual AS policy_expression,
  with_check AS with_check_expression,
  permissive,
  roles
FROM pg_policies
WHERE tablename = 'users'
ORDER BY policyname;
