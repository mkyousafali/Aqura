-- =====================================================
-- COMPREHENSIVE RECEIVING TASK ROLE ASSIGNMENT FIX
-- =====================================================
-- Problem: Systemic role mismatch between user role_type and task role_type
-- All users have generic roles (Position-based, Admin) but tasks expect specific roles
-- =====================================================

-- STEP 1: Analyze the current user role distribution
SELECT 
    'User Role Distribution' as report_type,
    u.role_type::text,
    COUNT(*) as user_count
FROM users u 
GROUP BY u.role_type::text
ORDER BY user_count DESC;

-- STEP 2: Analyze the task role distribution  
SELECT 
    'Task Role Distribution' as report_type,
    rt.role_type,
    COUNT(*) as task_count
FROM receiving_tasks rt 
WHERE rt.task_completed = false
GROUP BY rt.role_type
ORDER BY task_count DESC;

-- STEP 3: Show total mismatch count
SELECT 
    'Total Mismatch Count' as report_type,
    COUNT(*) as total_mismatched_tasks
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE rt.role_type != u.role_type::text
  AND rt.task_completed = false;

-- STEP 4: Identify what the correct user role mappings should be
-- Based on the task assignments, let's see which users are being assigned to which task types
SELECT 
    'User Task Assignment Pattern' as report_type,
    u.username,
    u.role_type::text as current_role,
    STRING_AGG(DISTINCT rt.role_type, ', ') as assigned_task_types,
    COUNT(*) as task_count
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE rt.task_completed = false
GROUP BY u.id, u.username, u.role_type::text
ORDER BY task_count DESC;

-- STEP 5: Show users who are consistently assigned to one type of task
-- These users should probably have their role_type updated to match
SELECT 
    'Suggested Role Updates' as report_type,
    u.id,
    u.username,
    u.role_type::text as current_role,
    rt.role_type as suggested_role,
    COUNT(*) as task_count,
    u.branch_id
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE rt.task_completed = false
GROUP BY u.id, u.username, u.role_type::text, rt.role_type, u.branch_id
HAVING COUNT(*) >= 5  -- Users with 5+ tasks of the same type
ORDER BY u.username, task_count DESC;

-- STEP 6: OPTION A - Update user role_types to match their task assignments
-- This fixes the root cause by giving users the correct roles
-- UNCOMMENT BELOW TO EXECUTE:

/*
-- Update Ayoob to be branch_manager (he has many branch_manager tasks)
UPDATE users 
SET role_type = 'branch_manager'::role_type_enum
WHERE username = 'Ayoob' 
  AND id = '05e7f43b-2214-4056-a792-30f466ad7cc7';

-- Update specific users based on their primary task assignments
-- You'll need to run the analysis above first to determine the right mappings

-- Example updates (adjust based on your analysis):
UPDATE users SET role_type = 'inventory_manager'::role_type_enum 
WHERE username = 'Hisham' AND id = '6f883b06-13a8-476b-86ce-a7a79553a4bd';

UPDATE users SET role_type = 'purchase_manager'::role_type_enum 
WHERE username = 'Abdhusathar' AND id = '807af948-0f5f-4f36-8925-747b152513c1';

UPDATE users SET role_type = 'accountant'::role_type_enum 
WHERE username = 'Ashique' AND id = '4ff8b724-ac89-4f55-b453-27145ffa3dd5';

UPDATE users SET role_type = 'shelf_stocker'::role_type_enum 
WHERE username = 'Firdous' AND id = '8b97aebf-5eeb-43f9-891c-da2010428ef5';

-- Add more updates based on the analysis results...
*/

-- STEP 7: OPTION B - Alternative: Delete all mismatched tasks and recreate with proper logic
-- CAUTION: This will delete all current tasks! Only use if tasks are test data.
/*
DELETE FROM receiving_tasks 
WHERE id IN (
    SELECT rt.id
    FROM receiving_tasks rt
    JOIN users u ON rt.assigned_user_id = u.id
    WHERE rt.role_type != u.role_type::text
      AND rt.task_completed = false
);
*/

-- STEP 8: After fixes, verify the solution worked
SELECT 
    'Post-Fix Verification' as report_type,
    CASE 
        WHEN COUNT(*) = 0 THEN 'SUCCESS: No more mismatches'
        ELSE CONCAT('REMAINING ISSUES: ', COUNT(*), ' mismatched tasks')
    END as result
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE rt.role_type != u.role_type::text
  AND rt.task_completed = false;

-- STEP 9: Show remaining issues after fix (if any)
SELECT 
    'Remaining Mismatches' as report_type,
    rt.id as task_id,
    rt.role_type as task_role_type,
    u.username,
    u.role_type::text as user_role_type
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE rt.role_type != u.role_type::text
  AND rt.task_completed = false
LIMIT 10;