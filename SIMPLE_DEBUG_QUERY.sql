-- =============================================
-- SIMPLE DEBUG: Check ERP sync status without RAISE NOTICE
-- =============================================

-- Check receiving_tasks with inventory_manager role
SELECT 
    'RECEIVING_TASKS' as debug_section,
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
LIMIT 5;

-- Check if trigger exists
SELECT 
    'TRIGGER_STATUS' as debug_section,
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation
FROM information_schema.triggers 
WHERE trigger_name = 'trg_task_completions_sync_erp'
   AND event_object_table = 'task_completions';

-- Check recent task_completions with ERP references
SELECT 
    'TASK_COMPLETIONS' as debug_section,
    tc.id,
    tc.task_id,
    tc.assignment_id,
    tc.completed_by,
    tc.completed_at,
    tc.erp_reference_number,
    tc.erp_reference_completed,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM receiving_tasks rt
            WHERE rt.task_id = tc.task_id
              AND rt.assignment_id = tc.assignment_id
              AND rt.role_type = 'inventory_manager'
        ) THEN 'YES'
        ELSE 'NO'
    END as has_receiving_task
FROM task_completions tc
WHERE tc.erp_reference_number IS NOT NULL
  AND TRIM(tc.erp_reference_number) != ''
ORDER BY tc.completed_at DESC
LIMIT 5;

-- Check for mismatched ERP references (task_completions vs receiving_records)
SELECT 
    'ERP_MISMATCHES' as debug_section,
    tc.task_id,
    tc.assignment_id,
    tc.erp_reference_number as task_completion_erp,
    rr.erp_purchase_invoice_reference as receiving_record_erp,
    rt.erp_reference_number as receiving_task_erp,
    tc.completed_at,
    CASE 
        WHEN tc.erp_reference_number = rr.erp_purchase_invoice_reference THEN 'MATCHED'
        WHEN tc.erp_reference_number != rr.erp_purchase_invoice_reference OR rr.erp_purchase_invoice_reference IS NULL THEN 'MISMATCH'
        ELSE 'UNKNOWN'
    END as sync_status
FROM task_completions tc
JOIN receiving_tasks rt ON tc.task_id = rt.task_id AND tc.assignment_id = rt.assignment_id
JOIN receiving_records rr ON rt.receiving_record_id = rr.id
WHERE rt.role_type = 'inventory_manager'
  AND tc.erp_reference_completed = true
  AND tc.erp_reference_number IS NOT NULL
  AND TRIM(tc.erp_reference_number) != ''
ORDER BY tc.completed_at DESC
LIMIT 10;