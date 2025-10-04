-- Simple Test Script for Frontend Compatibility
-- Run this to test if columns are accessible via REST API

-- 1. Test basic SELECT with all columns your frontend uses
SELECT 
    id,
    title,
    message,
    type,
    priority,          -- This should now work
    status,            -- This should now work  
    target_type,
    target_users,
    target_roles,
    target_branches,
    created_by,
    created_by_name,
    created_by_role,
    created_at,
    updated_at,
    task_id,
    task_assignment_id
FROM public.notifications 
ORDER BY created_at DESC 
LIMIT 5;

-- 2. Test INSERT with the exact structure your frontend uses
INSERT INTO public.notifications (
    title,
    message,
    type,
    priority,
    status,
    target_type,
    created_by,
    created_by_name,
    created_by_role
) VALUES (
    'Frontend Test Notification',
    'Testing if frontend can create notifications',
    'info',
    'medium',
    'published',
    'all_users',
    'test_user',
    'Test User',
    'Admin'
) RETURNING *;

-- 3. Verify the structure matches what your frontend expects
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'notifications' 
  AND table_schema = 'public'
  AND column_name IN ('priority', 'status', 'type', 'target_type')
ORDER BY column_name;