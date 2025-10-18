-- Quick Database Update Script
-- Apply just the critical fixes without the full function replacement

-- 1. Update existing receiving_tasks to remove ERP requirement for inventory managers
UPDATE receiving_tasks 
SET requires_erp_reference = false
WHERE role_type = 'inventory_manager';

-- 2. Update existing task assignments for inventory managers  
UPDATE task_assignments 
SET require_erp_reference = false
WHERE id IN (
    SELECT ta.id 
    FROM task_assignments ta
    JOIN receiving_tasks rt ON ta.id = rt.assignment_id
    WHERE rt.role_type = 'inventory_manager'
);

-- 3. Update tasks table to remove ERP requirement for inventory manager tasks
UPDATE tasks 
SET require_erp_reference = false
WHERE id IN (
    SELECT DISTINCT t.id 
    FROM tasks t
    JOIN task_assignments ta ON t.id = ta.task_id
    JOIN receiving_tasks rt ON ta.id = rt.assignment_id
    WHERE rt.role_type = 'inventory_manager'
);

-- Success message
DO $$ 
BEGIN 
    RAISE NOTICE '✅ Database updated: ERP requirements removed for existing inventory manager tasks';
END $$;