-- =============================================
-- FRESH ERP SYNC TEST: Create a new receiving record to test the complete workflow
-- =============================================

-- Step 1: Create a fresh receiving record without ERP reference
INSERT INTO receiving_records (
    bill_number,
    bill_date,
    bill_amount,
    vendor_id,
    branch_id,
    user_id,
    created_at
) VALUES (
    'FRESH-TEST-' || EXTRACT(EPOCH FROM NOW())::TEXT,
    now()::date,
    1000.00,
    (SELECT erp_vendor_id FROM vendors LIMIT 1),
    (SELECT id FROM branches LIMIT 1),
    (SELECT id FROM users LIMIT 1),
    now()
)
RETURNING id as new_receiving_record_id;

-- Step 2: Get the new receiving record ID for next steps
DO $$
DECLARE
    new_record_id UUID;
    new_task_id UUID;
    new_assignment_id UUID;
    test_erp_ref TEXT := 'LIVE-TEST-ERP-' || EXTRACT(EPOCH FROM NOW())::TEXT;
BEGIN
    -- Get the newly created receiving record
    SELECT id INTO new_record_id
    FROM receiving_records 
    WHERE bill_number LIKE 'FRESH-TEST-%'
    ORDER BY created_at DESC 
    LIMIT 1;
    
    RAISE NOTICE '🆕 Created new receiving record: %', new_record_id;
    
    -- Step 3: Create receiving_tasks for this record (simulate clearance certificate creation)
    INSERT INTO receiving_tasks (
        id,
        receiving_record_id,
        task_id,
        assignment_id,
        role_type,
        assigned_user_id,
        task_completed,
        created_at
    ) VALUES (
        gen_random_uuid(),
        new_record_id,
        gen_random_uuid(),
        gen_random_uuid(),
        'inventory_manager',
        (SELECT id FROM users LIMIT 1),
        false,
        now()
    )
    RETURNING task_id, assignment_id INTO new_task_id, new_assignment_id;
    
    RAISE NOTICE '📋 Created receiving_task with task_id: %, assignment_id: %', new_task_id, new_assignment_id;
    
    -- Step 4: Show BEFORE state
    DECLARE
        before_erp TEXT;
    BEGIN
        SELECT erp_purchase_invoice_reference INTO before_erp
        FROM receiving_records 
        WHERE id = new_record_id;
        
        RAISE NOTICE '📋 BEFORE - receiving_record ERP: %', COALESCE(before_erp, 'NULL');
    END;
    
    -- Step 5: Simulate inventory manager completing task with ERP reference
    RAISE NOTICE '⚡ Simulating inventory manager task completion with ERP: %', test_erp_ref;
    
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
        new_task_id,
        new_assignment_id,
        (SELECT id FROM users LIMIT 1)::TEXT,
        'Test Inventory Manager',
        (SELECT id FROM branches LIMIT 1),
        true,
        false,
        true,
        test_erp_ref,
        now()
    );
    
    -- Step 6: Wait for trigger and check AFTER state
    PERFORM pg_sleep(0.2);
    
    DECLARE
        after_erp TEXT;
        rt_erp TEXT;
    BEGIN
        SELECT 
            rr.erp_purchase_invoice_reference,
            rt.erp_reference_number
        INTO after_erp, rt_erp
        FROM receiving_records rr
        LEFT JOIN receiving_tasks rt ON rr.id = rt.receiving_record_id AND rt.role_type = 'inventory_manager'
        WHERE rr.id = new_record_id;
        
        RAISE NOTICE '📋 AFTER - receiving_record ERP: %', COALESCE(after_erp, 'NULL');
        RAISE NOTICE '📋 AFTER - receiving_task ERP: %', COALESCE(rt_erp, 'NULL');
        
        IF after_erp = test_erp_ref THEN
            RAISE NOTICE '✅ SUCCESS! ERP reference % was propagated to receiving_records!', test_erp_ref;
            RAISE NOTICE '🎉 The automatic ERP sync system is working perfectly!';
        ELSE
            RAISE NOTICE '❌ FAILURE! Expected %, got receiving_record: %, receiving_task: %', test_erp_ref, after_erp, rt_erp;
        END IF;
    END;
    
END $$;

-- Step 7: Clean up test data (optional - comment out if you want to keep for inspection)
-- DELETE FROM task_completions WHERE erp_reference_number LIKE 'LIVE-TEST-ERP-%';
-- DELETE FROM receiving_tasks WHERE receiving_record_id IN (
--     SELECT id FROM receiving_records WHERE bill_number LIKE 'FRESH-TEST-%'
-- );
-- DELETE FROM receiving_records WHERE bill_number LIKE 'FRESH-TEST-%';

-- Step 8: Show the complete workflow result
SELECT 
    'FRESH_TEST_RESULT' as test_section,
    rr.id as receiving_record_id,
    rr.bill_number,
    rr.erp_purchase_invoice_reference,
    tc.erp_reference_number as task_completion_erp,
    rt.erp_reference_number as receiving_task_erp,
    tc.completed_at,
    CASE 
        WHEN rr.erp_purchase_invoice_reference = tc.erp_reference_number THEN 'PERFECTLY_SYNCED'
        ELSE 'SYNC_ISSUE'
    END as final_status
FROM receiving_records rr
JOIN receiving_tasks rt ON rr.id = rt.receiving_record_id
JOIN task_completions tc ON rt.task_id = tc.task_id AND rt.assignment_id = tc.assignment_id
WHERE rr.bill_number LIKE 'FRESH-TEST-%'
   OR tc.erp_reference_number LIKE 'LIVE-TEST-ERP-%'
ORDER BY rr.created_at DESC;