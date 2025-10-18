-- Debug why 0 tasks were generated
-- Check the receiving record and see if inventory manager is assigned

SELECT 
    id,
    bill_number,
    inventory_manager_user_id,
    branch_manager_user_id,
    purchasing_manager_user_id,
    accountant_user_id,
    branch_id,
    vendor_id,
    created_at
FROM receiving_records 
WHERE id = '5bfddc22-200b-45aa-8066-ff7510006a0e';

-- Also check if any tasks were actually created for this receiving record
SELECT 
    rt.id,
    rt.role_type,
    rt.assigned_user_id,
    rt.requires_erp_reference,
    rt.requires_original_bill_upload,
    rt.task_completed,
    rt.created_at,
    t.title,
    t.status as task_status,
    ta.status as assignment_status
FROM receiving_tasks rt
LEFT JOIN tasks t ON rt.task_id = t.id
LEFT JOIN task_assignments ta ON rt.assignment_id = ta.id
WHERE rt.receiving_record_id = '5bfddc22-200b-45aa-8066-ff7510006a0e';

-- Check if the get_tasks_for_receiving_record function exists
SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'get_tasks_for_receiving_record' AND n.nspname = 'public';