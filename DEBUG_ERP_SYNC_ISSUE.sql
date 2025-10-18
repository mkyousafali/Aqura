-- =============================================
-- DEBUG: Why ERP sync trigger isn't working in real scenarios
-- =============================================

-- Check current receiving_tasks and their completion status
DO $$
DECLARE
    task_record RECORD;
    completion_record RECORD;
    counter INTEGER := 0;
BEGIN
    RAISE NOTICE '🔍 DEBUG: Investigating receiving_tasks and task_completions...';
    
    -- Get recent receiving_tasks with inventory_manager role
    FOR task_record IN 
        SELECT 
            rt.id as receiving_task_id,
            rt.receiving_record_id,
            rt.task_id,
            rt.assignment_id,
            rt.role_type,
            rt.task_completed,
            rt.erp_reference_number as rt_erp,
            rr.erp_purchase_invoice_reference as rr_erp,
            rr.created_at
        FROM receiving_tasks rt
        JOIN receiving_records rr ON rt.receiving_record_id = rr.id
        WHERE rt.role_type = 'inventory_manager'
        ORDER BY rr.created_at DESC
        LIMIT 5
    LOOP
        counter := counter + 1;
        RAISE NOTICE '📋 Task %: receiving_task_id=% receiving_record_id=% task_id=% assignment_id=%', 
                     counter, task_record.receiving_task_id, task_record.receiving_record_id, 
                     task_record.task_id, task_record.assignment_id;
        RAISE NOTICE '   └─ task_completed=% rt_erp=% rr_erp=%', 
                     task_record.task_completed, task_record.rt_erp, task_record.rr_erp;
        
        -- Check if there's a corresponding task_completion
        SELECT 
            id,
            completed_by,
            completed_at,
            erp_reference_number,
            erp_reference_completed
        INTO completion_record
        FROM task_completions
        WHERE task_id = task_record.task_id 
          AND assignment_id = task_record.assignment_id;
        
        IF FOUND THEN
            RAISE NOTICE '   ✅ Found task_completion: id=% completed_by=% completed_at=%', 
                         completion_record.id, completion_record.completed_by, completion_record.completed_at;
            RAISE NOTICE '   └─ erp_reference_number=% erp_reference_completed=%', 
                         completion_record.erp_reference_number, completion_record.erp_reference_completed;
        ELSE
            RAISE NOTICE '   ❌ No task_completion found for task_id=% assignment_id=%', 
                         task_record.task_id, task_record.assignment_id;
        END IF;
        
        RAISE NOTICE '';
    END LOOP;
    
    IF counter = 0 THEN
        RAISE NOTICE '❌ No inventory_manager receiving_tasks found';
    END IF;
    
END $$;

-- Check if trigger exists and is active
DO $$
DECLARE
    trigger_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_name = 'trg_task_completions_sync_erp'
          AND event_object_table = 'task_completions'
    ) INTO trigger_exists;
    
    IF trigger_exists THEN
        RAISE NOTICE '✅ Trigger trg_task_completions_sync_erp exists and is active';
    ELSE
        RAISE NOTICE '❌ Trigger trg_task_completions_sync_erp does not exist or is not active';
    END IF;
END $$;

-- Check recent task_completions with ERP references
DO $$
DECLARE
    completion_record RECORD;
    counter INTEGER := 0;
BEGIN
    RAISE NOTICE '🔍 Recent task_completions with ERP references:';
    
    FOR completion_record IN
        SELECT 
            id,
            task_id,
            assignment_id,
            completed_by,
            completed_at,
            erp_reference_number,
            erp_reference_completed
        FROM task_completions
        WHERE erp_reference_number IS NOT NULL
          AND TRIM(erp_reference_number) != ''
        ORDER BY completed_at DESC
        LIMIT 5
    LOOP
        counter := counter + 1;
        RAISE NOTICE '📝 Completion %: id=% task_id=% assignment_id=%', 
                     counter, completion_record.id, completion_record.task_id, completion_record.assignment_id;
        RAISE NOTICE '   └─ erp=% completed=% completed_at=%', 
                     completion_record.erp_reference_number, completion_record.erp_reference_completed, 
                     completion_record.completed_at;
        
        -- Check if this has a corresponding receiving_task
        DECLARE
            rt_exists BOOLEAN;
        BEGIN
            SELECT EXISTS (
                SELECT 1 FROM receiving_tasks rt
                WHERE rt.task_id = completion_record.task_id
                  AND rt.assignment_id = completion_record.assignment_id
                  AND rt.role_type = 'inventory_manager'
            ) INTO rt_exists;
            
            RAISE NOTICE '   └─ has_receiving_task=%', rt_exists;
        END;
    END LOOP;
    
    IF counter = 0 THEN
        RAISE NOTICE '❌ No task_completions with ERP references found';
    END IF;
END $$;

-- Test trigger manually with a real record
DO $$
DECLARE
    test_task_id UUID;
    test_assignment_id UUID;
    test_completion_id UUID;
BEGIN
    -- Find a real receiving_task that doesn't have ERP yet
    SELECT rt.task_id, rt.assignment_id
    INTO test_task_id, test_assignment_id
    FROM receiving_tasks rt
    JOIN receiving_records rr ON rt.receiving_record_id = rr.id
    WHERE rt.role_type = 'inventory_manager'
      AND (rr.erp_purchase_invoice_reference IS NULL OR rr.erp_purchase_invoice_reference = '')
      AND (rt.erp_reference_number IS NULL OR rt.erp_reference_number = '')
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE '🧪 Testing trigger with real task_id=% assignment_id=%', test_task_id, test_assignment_id;
        
        -- Check if task_completion exists
        SELECT id INTO test_completion_id
        FROM task_completions
        WHERE task_id = test_task_id AND assignment_id = test_assignment_id;
        
        IF FOUND THEN
            RAISE NOTICE '⚡ Updating existing task_completion to trigger ERP sync...';
            UPDATE task_completions
            SET 
                erp_reference_number = 'MANUAL-TEST-' || EXTRACT(EPOCH FROM NOW())::TEXT,
                erp_reference_completed = true
            WHERE id = test_completion_id;
        ELSE
            RAISE NOTICE '⚡ Creating new task_completion to trigger ERP sync...';
            INSERT INTO task_completions (
                task_id,
                assignment_id,
                completed_by,
                completed_at,
                erp_reference_number,
                erp_reference_completed
            ) VALUES (
                test_task_id,
                test_assignment_id,
                (SELECT id FROM users WHERE role = 'admin' LIMIT 1),
                now(),
                'MANUAL-TEST-' || EXTRACT(EPOCH FROM NOW())::TEXT,
                true
            );
        END IF;
        
        RAISE NOTICE '✅ Manual trigger test completed - check receiving_records for new ERP reference';
    ELSE
        RAISE NOTICE '❌ No suitable receiving_task found for manual trigger test';
    END IF;
END $$;

DO $$ 
BEGIN 
    RAISE NOTICE '🔍 Debug complete - check the logs above to identify the issue';
END $$;