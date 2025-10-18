-- =============================================
-- FIX TRIGGER CONFLICT: Check and resolve duplicate ERP sync triggers
-- =============================================

-- Check what triggers currently exist on task_completions
SELECT 
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'task_completions'
ORDER BY trigger_name;

-- Check if the old trigger function exists
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname IN ('trigger_sync_erp_reference_on_task_completion', 'trg_task_completions_sync_erp');

-- Drop our new trigger since the old one should work
DROP TRIGGER IF EXISTS trg_task_completions_sync_erp ON task_completions;
DROP FUNCTION IF EXISTS trg_task_completions_sync_erp();

-- Ensure the migration 77 trigger is working properly
-- Check recent task_completions and see if they have matching receiving_record updates

SELECT 
    'TRIGGER_TEST' as debug_section,
    tc.id as task_completion_id,
    tc.task_id,
    tc.assignment_id,
    tc.erp_reference_number,
    tc.erp_reference_completed,
    tc.completed_at,
    rt.receiving_record_id,
    rr.erp_purchase_invoice_reference,
    CASE 
        WHEN tc.erp_reference_number = rr.erp_purchase_invoice_reference THEN 'SYNCED'
        WHEN tc.erp_reference_number IS NOT NULL AND rr.erp_purchase_invoice_reference IS NULL THEN 'NEEDS_SYNC'
        WHEN tc.erp_reference_number != rr.erp_purchase_invoice_reference THEN 'MISMATCH'
        ELSE 'NO_ERP'
    END as sync_status
FROM task_completions tc
JOIN receiving_tasks rt ON tc.task_id = rt.task_id AND tc.assignment_id = rt.assignment_id
JOIN receiving_records rr ON rt.receiving_record_id = rr.id
WHERE rt.role_type = 'inventory_manager'
  AND tc.erp_reference_number IS NOT NULL
  AND TRIM(tc.erp_reference_number) != ''
ORDER BY tc.completed_at DESC
LIMIT 10;

-- Manual test: Create a test task completion and see if trigger works
DO $$
DECLARE
    test_task_id UUID;
    test_assignment_id UUID;
    test_receiving_record_id UUID;
    test_erp_ref TEXT := 'TRIGGER-FIX-TEST-' || EXTRACT(EPOCH FROM NOW())::TEXT;
    before_erp TEXT;
    after_erp TEXT;
BEGIN
    -- Find a receiving task without ERP reference
    SELECT rt.task_id, rt.assignment_id, rt.receiving_record_id
    INTO test_task_id, test_assignment_id, test_receiving_record_id
    FROM receiving_tasks rt
    JOIN receiving_records rr ON rt.receiving_record_id = rr.id
    WHERE rt.role_type = 'inventory_manager'
      AND (rr.erp_purchase_invoice_reference IS NULL OR rr.erp_purchase_invoice_reference = '')
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE 'Testing trigger with task_id=% assignment_id=% receiving_record_id=%', 
                     test_task_id, test_assignment_id, test_receiving_record_id;
        
        -- Get BEFORE state
        SELECT erp_purchase_invoice_reference INTO before_erp
        FROM receiving_records 
        WHERE id = test_receiving_record_id;
        
        RAISE NOTICE 'BEFORE: receiving_record ERP = %', before_erp;
        
        -- Insert/Update task_completion with ERP reference
        INSERT INTO task_completions (
            task_id,
            assignment_id,
            completed_by,
            completed_by_name,
            completed_by_branch_id,
            task_finished_completed,
            photo_uploaded_completed,
            erp_reference_completed,
            erp_reference_number,
            completed_at
        ) VALUES (
            test_task_id,
            test_assignment_id,
            (SELECT id FROM users WHERE role = 'admin' LIMIT 1)::TEXT,
            'Test User',
            (SELECT id FROM branches LIMIT 1),
            true,
            false,
            true,
            test_erp_ref,
            now()
        )
        ON CONFLICT (task_id, assignment_id) DO UPDATE SET
            erp_reference_completed = EXCLUDED.erp_reference_completed,
            erp_reference_number = EXCLUDED.erp_reference_number,
            completed_at = EXCLUDED.completed_at;
        
        -- Small delay for trigger processing
        PERFORM pg_sleep(0.1);
        
        -- Get AFTER state
        SELECT erp_purchase_invoice_reference INTO after_erp
        FROM receiving_records 
        WHERE id = test_receiving_record_id;
        
        RAISE NOTICE 'AFTER: receiving_record ERP = %', after_erp;
        
        IF after_erp = test_erp_ref THEN
            RAISE NOTICE '✅ TRIGGER WORKING: ERP reference % propagated successfully!', test_erp_ref;
        ELSE
            RAISE NOTICE '❌ TRIGGER NOT WORKING: Expected %, got %', test_erp_ref, after_erp;
        END IF;
    ELSE
        RAISE NOTICE '⚠️ No suitable test record found';
    END IF;
END $$;