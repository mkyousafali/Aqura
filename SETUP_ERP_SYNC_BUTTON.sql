-- =============================================
-- RUN THIS SQL IN SUPABASE SQL EDITOR FIRST
-- This enables the ERP sync button functionality
-- =============================================

-- 1. First run the manual ERP sync functions (copy from 79_manual_erp_sync_functions.sql)

-- Function to sync ERP reference for a specific receiving record
CREATE OR REPLACE FUNCTION sync_erp_reference_for_receiving_record(
    receiving_record_id_param UUID
)
RETURNS JSONB AS $$
DECLARE
    sync_record RECORD;
    updated_count INTEGER := 0;
    result_json JSONB;
BEGIN
    -- Find the task completion with ERP reference for this receiving record
    SELECT 
        tc.erp_reference_number,
        tc.erp_reference_completed,
        rt.role_type,
        rr.erp_purchase_invoice_reference as current_erp,
        tc.completed_at,
        tc.completed_by
    INTO sync_record
    FROM receiving_records rr
    JOIN receiving_tasks rt ON rr.id = rt.receiving_record_id
    JOIN task_completions tc ON rt.task_id = tc.task_id AND rt.assignment_id = tc.assignment_id
    WHERE rr.id = receiving_record_id_param
      AND rt.role_type = 'inventory_manager'
      AND tc.erp_reference_completed = true
      AND tc.erp_reference_number IS NOT NULL
      AND TRIM(tc.erp_reference_number) != ''
    ORDER BY tc.completed_at DESC
    LIMIT 1;

    -- If we found a task completion with ERP reference
    IF FOUND THEN
        -- Check if sync is needed
        IF sync_record.current_erp IS NULL OR sync_record.current_erp != TRIM(sync_record.erp_reference_number) THEN
            -- Update the receiving record
            UPDATE receiving_records 
            SET 
                erp_purchase_invoice_reference = TRIM(sync_record.erp_reference_number),
                updated_at = now()
            WHERE id = receiving_record_id_param;
            
            GET DIAGNOSTICS updated_count = ROW_COUNT;
            
            result_json := jsonb_build_object(
                'success', true,
                'synced', true,
                'updated_count', updated_count,
                'erp_reference', TRIM(sync_record.erp_reference_number),
                'previous_erp', sync_record.current_erp,
                'completed_by', sync_record.completed_by,
                'completed_at', sync_record.completed_at,
                'message', format('ERP reference %s synced successfully', TRIM(sync_record.erp_reference_number))
            );
        ELSE
            result_json := jsonb_build_object(
                'success', true,
                'synced', false,
                'updated_count', 0,
                'erp_reference', sync_record.current_erp,
                'message', 'ERP reference already synced - no update needed'
            );
        END IF;
    ELSE
        result_json := jsonb_build_object(
            'success', true,
            'synced', false,
            'updated_count', 0,
            'message', 'No completed inventory manager task with ERP reference found'
        );
    END IF;
    
    RETURN result_json;

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'error_code', SQLSTATE
        );
END;
$$ LANGUAGE plpgsql;

-- Function to check ERP sync status for a specific receiving record
CREATE OR REPLACE FUNCTION check_erp_sync_status_for_record(
    receiving_record_id_param UUID
)
RETURNS JSONB AS $$
DECLARE
    status_record RECORD;
    result_json JSONB;
BEGIN
    -- Get comprehensive sync status information
    SELECT 
        rr.erp_purchase_invoice_reference,
        tc.erp_reference_number as task_erp_reference,
        tc.erp_reference_completed,
        tc.completed_at as task_completed_at,
        tc.completed_by,
        rt.role_type,
        rt.task_completed as receiving_task_completed,
        CASE 
            WHEN tc.erp_reference_completed = true 
                 AND tc.erp_reference_number IS NOT NULL 
                 AND TRIM(tc.erp_reference_number) != ''
                 AND rr.erp_purchase_invoice_reference = TRIM(tc.erp_reference_number)
            THEN 'SYNCED'
            WHEN tc.erp_reference_completed = true 
                 AND tc.erp_reference_number IS NOT NULL 
                 AND TRIM(tc.erp_reference_number) != ''
                 AND (rr.erp_purchase_invoice_reference IS NULL 
                      OR rr.erp_purchase_invoice_reference != TRIM(tc.erp_reference_number))
            THEN 'NEEDS_SYNC'
            WHEN tc.erp_reference_completed = false 
                 OR tc.erp_reference_number IS NULL 
                 OR TRIM(tc.erp_reference_number) = ''
            THEN 'NO_ERP_REFERENCE'
            ELSE 'UNKNOWN'
        END as sync_status
    INTO status_record
    FROM receiving_records rr
    LEFT JOIN receiving_tasks rt ON rr.id = rt.receiving_record_id AND rt.role_type = 'inventory_manager'
    LEFT JOIN task_completions tc ON rt.task_id = tc.task_id AND rt.assignment_id = tc.assignment_id
    WHERE rr.id = receiving_record_id_param
    ORDER BY tc.completed_at DESC
    LIMIT 1;

    IF FOUND THEN
        result_json := jsonb_build_object(
            'success', true,
            'receiving_record_id', receiving_record_id_param,
            'current_erp_reference', status_record.erp_purchase_invoice_reference,
            'task_erp_reference', status_record.task_erp_reference,
            'task_erp_completed', status_record.erp_reference_completed,
            'task_completed_at', status_record.task_completed_at,
            'task_completed_by', status_record.completed_by,
            'receiving_task_completed', status_record.receiving_task_completed,
            'sync_status', status_record.sync_status,
            'sync_needed', status_record.sync_status = 'NEEDS_SYNC',
            'can_sync', status_record.sync_status IN ('NEEDS_SYNC', 'SYNCED')
        );
    ELSE
        result_json := jsonb_build_object(
            'success', false,
            'error', 'Receiving record not found'
        );
    END IF;
    
    RETURN result_json;

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'error_code', SQLSTATE
        );
END;
$$ LANGUAGE plpgsql;

-- Success message
DO $$ 
BEGIN 
    RAISE NOTICE '✅ ERP Sync functions ready! The sync button in Receiving Records window will now work.';
END $$;