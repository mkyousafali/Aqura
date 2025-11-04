-- =====================================================
-- FIX RECEIVING TASK ROLE ASSIGNMENT MISMATCH
-- =====================================================
-- Problem: Users are assigned to receiving tasks that don't match their role
-- Solution: Check and fix task assignments to ensure users are only assigned 
--           to tasks that match their actual role type
-- =====================================================

-- First, let's check the users table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;

-- Check what we're working with for the specific user
SELECT 
    id,
    username,
    role_type,
    branch_id,
    user_type,
    created_at
FROM users 
WHERE id = '05e7f43b-2214-4056-a792-30f466ad7cc7';

-- First, let's see the current problem (with type casting)
SELECT 
    rt.id as task_id,
    rt.role_type as task_role_type,
    rt.assigned_user_id,
    u.username,
    u.role_type::text as user_role_type
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE rt.role_type != u.role_type::text
  AND rt.task_completed = false;

-- Show specific problem case
SELECT 
    rt.id as task_id,
    rt.role_type as task_role_type,
    rt.assigned_user_id,
    u.username,
    u.role_type::text as user_role_type,
    u.branch_id
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE rt.assigned_user_id = '05e7f43b-2214-4056-a792-30f466ad7cc7'
  AND rt.id = '05605a99-f8bd-4e0a-808d-1e4e888801c1';

-- Find the correct inventory manager for this branch
SELECT 
    u.id,
    u.username,
    u.role_type::text as role_type,
    u.branch_id
FROM users u
WHERE u.role_type::text = 'inventory_manager'
  AND u.branch_id = (
    SELECT rr.branch_id 
    FROM receiving_records rr 
    WHERE rr.id = '1daadddd-4126-4e0f-8658-639a2db0233f'
  );

-- OPTION 1: Reassign this specific task to the correct inventory manager
-- (Uncomment and run if you want to fix this specific task)
/*
UPDATE receiving_tasks 
SET assigned_user_id = (
    SELECT u.id
    FROM users u
    WHERE u.role_type::text = 'inventory_manager'
      AND u.branch_id = (
        SELECT rr.branch_id 
        FROM receiving_records rr 
        WHERE rr.id = '1daadddd-4126-4e0f-8658-639a2db0233f'
      )
    LIMIT 1
)
WHERE id = '05605a99-f8bd-4e0a-808d-1e4e888801c1'
  AND task_completed = false;
*/

-- OPTION 2: Create a new branch manager task for this user and remove the inventory manager task
-- (This assumes the branch manager should have their own task type)
/*
-- First, check if there's already a branch_manager task for this receiving record
SELECT * FROM receiving_tasks 
WHERE receiving_record_id = '1daadddd-4126-4e0f-8658-639a2db0233f' 
  AND role_type = 'branch_manager';

-- If no branch manager task exists, create one and remove the misassigned inventory task
INSERT INTO receiving_tasks (
    receiving_record_id,
    role_type,
    assigned_user_id,
    title,
    description,
    template_id,
    requires_erp_reference,
    requires_original_bill_upload,
    task_status,
    created_at
)
SELECT 
    '1daadddd-4126-4e0f-8658-639a2db0233f',
    'branch_manager',
    '05e7f43b-2214-4056-a792-30f466ad7cc7',
    'Complete Branch Manager Review',
    'Review and approve the receiving process as Branch Manager',
    (SELECT id FROM receiving_task_templates WHERE role_type::text = 'branch_manager' LIMIT 1),
    false,
    false,
    'pending',
    NOW()
WHERE NOT EXISTS (
    SELECT 1 FROM receiving_tasks 
    WHERE receiving_record_id = '1daadddd-4126-4e0f-8658-639a2db0233f' 
      AND role_type = 'branch_manager'
);

-- Remove the misassigned inventory manager task
DELETE FROM receiving_tasks 
WHERE id = '05605a99-f8bd-4e0a-808d-1e4e888801c1'
  AND role_type = 'inventory_manager'
  AND assigned_user_id = '05e7f43b-2214-4056-a792-30f466ad7cc7'
  AND task_completed = false;
*/

-- Check for all role mismatches across the system
SELECT 
    'Role Mismatch Summary' as report_type,
    COUNT(*) as total_mismatched_tasks
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE rt.role_type != u.role_type::text
  AND rt.task_completed = false;

-- Detailed report of all mismatches
SELECT 
    rt.id as task_id,
    rt.role_type as task_role_type,
    rt.assigned_user_id,
    u.username,
    u.role_type::text as user_role_type,
    rr.branch_id,
    rt.created_at
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
JOIN receiving_records rr ON rt.receiving_record_id = rr.id
WHERE rt.role_type != u.role_type::text
  AND rt.task_completed = false
ORDER BY rt.created_at DESC;