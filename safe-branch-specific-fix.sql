-- =====================================================
-- SAFE BRANCH-SPECIFIC ROLE ASSIGNMENT FIX
-- =====================================================
-- Problem: Ayoob (Branch 2) can't complete inventory_manager tasks 
-- Root Cause: Branch 2 has no dedicated inventory_manager
-- Solution: Branch-specific position mapping without affecting other branches
-- =====================================================

-- STEP 1: Create position_role_mapping table (if not exists)
CREATE TABLE IF NOT EXISTS position_role_mapping (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    position_id UUID NOT NULL,
    functional_role_type TEXT NOT NULL,
    branch_id INTEGER NULL, -- Branch-specific mapping
    is_primary_role BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(position_id, branch_id, functional_role_type)
);

-- STEP 2: Insert safe mappings that match current working assignments
-- Only map what we know works, branch by branch

-- BRANCH 1 MAPPINGS (Working correctly)
INSERT INTO position_role_mapping (position_id, functional_role_type, branch_id, is_primary_role) VALUES
-- Anas - Branch Manager Branch 1
('a27a28e1-a99d-4d10-bb9f-931cbcd30c11', 'branch_manager', 1, true),
-- Rabith - Warehouse Handler Branch 1  
('5939fa8c-a64f-42aa-958b-2f6be648c991', 'warehouse_handler', 1, true),
-- Ramshad - Accountant Branch 1
('4f7d8239-4c59-4dad-ab40-b854f875ffe2', 'accountant', 1, true),
-- Rashad - Shelf Stocker Branch 1
('172d87af-6224-455b-9c7c-741761ec4ac3', 'shelf_stocker', 1, true),
-- Isthiyaque - Night Supervisor Branch 1
('a27a28e1-a99d-4d10-bb9f-931cbcd30c11', 'night_supervisor', 1, false),
-- Abdhusathar - Purchase Manager (Admin, works across branches)
(NULL, 'purchase_manager', NULL, true)  -- Special case for Admin users

ON CONFLICT (position_id, branch_id, functional_role_type) DO NOTHING;

-- BRANCH 2 MAPPINGS (The problematic branch - needs special handling)
INSERT INTO position_role_mapping (position_id, functional_role_type, branch_id, is_primary_role) VALUES
-- Ayoob - Branch Manager AND Inventory Manager (dual role for Branch 2 only)
('91686ffe-58ac-4c42-9da4-66e0e7b13b80', 'branch_manager', 2, true),
('91686ffe-58ac-4c42-9da4-66e0e7b13b80', 'inventory_manager', 2, false), -- Secondary role
-- Muhsin - Night Supervisor Branch 2
('a27a28e1-a99d-4d10-bb9f-931cbcd30c11', 'night_supervisor', 2, true),
-- Ashique - Accountant Branch 2
('4f7d8239-4c59-4dad-ab40-b854f875ffe2', 'accountant', 2, true),
-- Firdous - Shelf Stocker Branch 2
('172d87af-6224-455b-9c7c-741761ec4ac3', 'shelf_stocker', 2, true),
-- shantu - Warehouse Handler Branch 2
('172d87af-6224-455b-9c7c-741761ec4ac3', 'warehouse_handler', 2, false) -- Secondary role for shelf stockers

ON CONFLICT (position_id, branch_id, functional_role_type) DO NOTHING;

-- BRANCH 3 MAPPINGS (Working correctly)
INSERT INTO position_role_mapping (position_id, functional_role_type, branch_id, is_primary_role) VALUES
-- Hisham - Inventory Manager Branch 3
('fd146e59-6875-40b1-bccd-0806e1bbd956', 'inventory_manager', 3, true),
-- Alin arfath - Warehouse Handler Branch 3 (also has inventory manager position)
('fd146e59-6875-40b1-bccd-0806e1bbd956', 'warehouse_handler', 3, false),
-- Muhammed fouzan - Accountant Branch 3
('4f7d8239-4c59-4dad-ab40-b854f875ffe2', 'accountant', 3, true),
-- Rasheed - Branch Manager Branch 3
('91686ffe-58ac-4c42-9da4-66e0e7b13b80', 'branch_manager', 3, true),
-- Noorudheen - Night Supervisor Branch 3
('a27a28e1-a99d-4d10-bb9f-931cbcd30c11', 'night_supervisor', 3, true)

ON CONFLICT (position_id, branch_id, functional_role_type) DO NOTHING;

-- STEP 3: Create a safe function to check if user can complete task
CREATE OR REPLACE FUNCTION can_user_complete_task(
    user_id_param UUID,
    task_role_type_param TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    user_record RECORD;
    can_complete BOOLEAN := false;
BEGIN
    -- Get user details
    SELECT u.username, u.role_type, u.position_id, u.branch_id
    INTO user_record
    FROM users u 
    WHERE u.id = user_id_param;
    
    -- Admin users can complete any task
    IF user_record.role_type IN ('Admin', 'Master Admin') THEN
        RETURN true;
    END IF;
    
    -- Check position mapping for this specific branch
    SELECT EXISTS(
        SELECT 1 FROM position_role_mapping prm 
        WHERE prm.position_id = user_record.position_id
        AND prm.functional_role_type = task_role_type_param
        AND (prm.branch_id = user_record.branch_id OR prm.branch_id IS NULL)
    ) INTO can_complete;
    
    -- Special case: If no mapping found, check if it's a legacy role match
    IF NOT can_complete THEN
        can_complete := (user_record.role_type::text = task_role_type_param);
    END IF;
    
    RETURN can_complete;
END;
$$ LANGUAGE plpgsql;

-- STEP 4: Verify the fix works for our specific cases
-- Test Ayoob's access to both branch_manager and inventory_manager tasks
SELECT 
    'Ayoob Task Access Test' as test_name,
    can_user_complete_task('05e7f43b-2214-4056-a792-30f466ad7cc7', 'branch_manager') as can_do_branch_manager,
    can_user_complete_task('05e7f43b-2214-4056-a792-30f466ad7cc7', 'inventory_manager') as can_do_inventory_manager;

-- Test that other branches are not affected
SELECT 
    'Other Branch Test' as test_name,
    u.username,
    u.branch_id,
    can_user_complete_task(u.id, 'inventory_manager') as can_do_inventory,
    can_user_complete_task(u.id, 'branch_manager') as can_do_branch_mgr
FROM users u 
WHERE u.username IN ('Hisham', 'Anas', 'Rasheed')
ORDER BY u.branch_id;

-- STEP 5: Create a view to see current role assignments
CREATE OR REPLACE VIEW user_functional_roles AS
SELECT 
    u.id,
    u.username,
    u.branch_id,
    u.role_type as system_role,
    u.position_id,
    prm.functional_role_type,
    prm.is_primary_role,
    CASE WHEN prm.branch_id IS NULL THEN 'All Branches' ELSE prm.branch_id::text END as applicable_branch
FROM users u
LEFT JOIN position_role_mapping prm ON u.position_id = prm.position_id 
    AND (prm.branch_id = u.branch_id OR prm.branch_id IS NULL)
WHERE u.status = 'active'
ORDER BY u.branch_id, u.username, prm.is_primary_role DESC;

-- STEP 6: Show the results for verification
SELECT 'User Functional Roles by Branch' as report_title;
SELECT * FROM user_functional_roles WHERE username IN ('Ayoob', 'Hisham', 'Anas', 'Ashique', 'Abdhusathar');

-- STEP 7: Safe cleanup - only for Branch 2 if needed
-- This reassigns some inventory tasks from Ayoob to proper inventory managers in other branches
-- ONLY if you want to reduce Ayoob's workload
/*
-- Move some inventory tasks from Branch 2 to Branch 3 (where there's a proper inventory manager)
UPDATE receiving_tasks 
SET assigned_user_id = '6f883b06-13a8-476b-86ce-a7a79553a4bd', -- Hisham (Branch 3 inventory manager)
    updated_at = NOW()
WHERE role_type = 'inventory_manager' 
  AND assigned_user_id = '05e7f43b-2214-4056-a792-30f466ad7cc7' -- Ayoob
  AND task_completed = false
  AND id IN (
    SELECT rt.id 
    FROM receiving_tasks rt
    JOIN receiving_records rr ON rt.receiving_record_id = rr.id
    WHERE rt.role_type = 'inventory_manager' 
      AND rt.assigned_user_id = '05e7f43b-2214-4056-a792-30f466ad7cc7'
      AND rt.task_completed = false
    ORDER BY rt.created_at 
    LIMIT 10  -- Only move 10 tasks, keep the rest for Ayoob
  );
*/

-- STEP 8: Final verification
SELECT 
    'Final Verification' as report_type,
    COUNT(CASE WHEN can_user_complete_task(rt.assigned_user_id, rt.role_type) THEN 1 END) as can_complete_count,
    COUNT(*) as total_active_tasks,
    ROUND(
        100.0 * COUNT(CASE WHEN can_user_complete_task(rt.assigned_user_id, rt.role_type) THEN 1 END) / COUNT(*), 
        2
    ) as completion_success_rate
FROM receiving_tasks rt
WHERE rt.task_completed = false;

-- Show remaining problematic assignments by branch
SELECT 
    'Remaining Issues by Branch' as report_type,
    u.branch_id,
    rt.role_type,
    COUNT(*) as problem_tasks
FROM receiving_tasks rt
JOIN users u ON rt.assigned_user_id = u.id
WHERE rt.task_completed = false
  AND NOT can_user_complete_task(rt.assigned_user_id, rt.role_type)
GROUP BY u.branch_id, rt.role_type
ORDER BY u.branch_id, problem_tasks DESC;