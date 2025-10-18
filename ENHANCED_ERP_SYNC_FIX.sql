-- =============================================
-- DIRECT ERP SYNC FIX - FOR EXISTING RECEIVING RECORDS
-- This handles records that already have ERP references but weren't created through the task system
-- =============================================

-- Function to sync ERP reference (works with existing data)
CREATE OR REPLACE FUNCTION sync_erp_reference_for_receiving_record(
    receiving_record_id_param UUID
)
RETURNS JSONB AS $$
DECLARE
    sync_record RECORD;
    updated_count INTEGER := 0;
    result_json JSONB;
BEGIN
    RAISE NOTICE 'Starting ERP sync for receiving_record_id: %', receiving_record_id_param;
    
    -- First, try to find task completion with ERP reference
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
        RAISE NOTICE 'Found task completion with ERP: %', sync_record.erp_reference_number;
        
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
                'message', format('ERP reference %s synced from task completion', TRIM(sync_record.erp_reference_number))
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
        RAISE NOTICE 'No task completion found, checking for existing ERP reference';
        
        -- If no task completion, check if the record already has an ERP reference
        SELECT 
            rr.erp_purchase_invoice_reference as current_erp,
            rr.created_at,
            rr.updated_at
        INTO sync_record
        FROM receiving_records rr
        WHERE rr.id = receiving_record_id_param;
        
        IF FOUND AND sync_record.current_erp IS NOT NULL AND TRIM(sync_record.current_erp) != '' THEN
            result_json := jsonb_build_object(
                'success', true,
                'synced', false,
                'updated_count', 0,
                'erp_reference', sync_record.current_erp,
                'message', format('ERP reference %s already exists (legacy record)', sync_record.current_erp)
            );
        ELSE
            result_json := jsonb_build_object(
                'success', true,
                'synced', false,
                'updated_count', 0,
                'message', 'No ERP reference available - inventory manager task not completed'
            );
        END IF;
    END IF;
    
    RETURN result_json;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR in sync function: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'error_code', SQLSTATE
        );
END;
$$ LANGUAGE plpgsql;

-- Function to check ERP sync status (enhanced for existing data)
CREATE OR REPLACE FUNCTION check_erp_sync_status_for_record(
    receiving_record_id_param UUID
)
RETURNS JSONB AS $$
DECLARE
    status_record RECORD;
    result_json JSONB;
    has_tasks BOOLEAN := false;
BEGIN
    RAISE NOTICE 'Checking sync status for receiving_record_id: %', receiving_record_id_param;
    
    -- Check if this record has any receiving tasks
    SELECT EXISTS (
        SELECT 1 FROM receiving_tasks rt 
        WHERE rt.receiving_record_id = receiving_record_id_param
    ) INTO has_tasks;
    
    RAISE NOTICE 'Record has receiving tasks: %', has_tasks;
    
    IF has_tasks THEN
        -- Get task-based sync status information
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
    ELSE
        -- For legacy records without tasks, check if they have ERP references
        SELECT 
            rr.erp_purchase_invoice_reference,
            NULL::text as task_erp_reference,
            NULL::boolean as erp_reference_completed,
            NULL::timestamptz as task_completed_at,
            NULL::text as completed_by,
            NULL::text as role_type,
            NULL::boolean as receiving_task_completed,
            CASE 
                WHEN rr.erp_purchase_invoice_reference IS NOT NULL 
                     AND TRIM(rr.erp_purchase_invoice_reference) != ''
                THEN 'LEGACY_WITH_ERP'
                ELSE 'LEGACY_NO_ERP'
            END as sync_status
        INTO status_record
        FROM receiving_records rr
        WHERE rr.id = receiving_record_id_param;
    END IF;

    RAISE NOTICE 'Status check - FOUND: %, Current ERP: %, Task ERP: %, Status: %', 
                 FOUND, status_record.erp_purchase_invoice_reference, 
                 status_record.task_erp_reference, status_record.sync_status;

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
            'can_sync', status_record.sync_status IN ('NEEDS_SYNC', 'SYNCED', 'LEGACY_WITH_ERP'),
            'has_tasks', has_tasks
        );
    ELSE
        RAISE NOTICE 'No record found for receiving_record_id: %', receiving_record_id_param;
        result_json := jsonb_build_object(
            'success', false,
            'error', 'Receiving record not found'
        );
    END IF;
    
    RETURN result_json;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR in status check function: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'error_code', SQLSTATE
        );
END;
$$ LANGUAGE plpgsql;

-- Test with existing records
DO $$
DECLARE
    test_record RECORD;
    test_result JSONB;
    counter INTEGER := 0;
BEGIN
    -- Test with several receiving records
    FOR test_record IN 
        SELECT id, erp_purchase_invoice_reference 
        FROM receiving_records 
        WHERE erp_purchase_invoice_reference IS NOT NULL
        LIMIT 3
    LOOP
        counter := counter + 1;
        RAISE NOTICE '🧪 Test %: Testing with receiving_record_id: % (ERP: %)', 
                     counter, test_record.id, test_record.erp_purchase_invoice_reference;
        
        -- Test the status check function
        SELECT check_erp_sync_status_for_record(test_record.id) INTO test_result;
        RAISE NOTICE '📊 Test % result: %', counter, test_result;
    END LOOP;
    
    IF counter = 0 THEN
        RAISE NOTICE '❌ No receiving records with ERP references found for testing';
    END IF;
END $$;

-- Success message
DO $$ 
BEGIN 
    RAISE NOTICE '✅ Enhanced ERP Sync functions ready!';
    RAISE NOTICE 'Now supports both task-based records and legacy records with existing ERP references.';
    RAISE NOTICE 'The sync buttons should show appropriate status for all records.';
END $$;

-- =============================================
-- TRIGGER: Propagate ERP reference from task_completions
-- When an inventory_manager completes a task with an ERP reference,
-- update receiving_tasks.erp_reference_number and receiving_records.erp_purchase_invoice_reference
-- =============================================

CREATE OR REPLACE FUNCTION trg_task_completions_sync_erp()
RETURNS TRIGGER AS $$
DECLARE
    v_rt_id UUID;
    v_receiving_record_id UUID;
    v_erp TEXT := NULL;
BEGIN
    RAISE NOTICE '[trg_task_completions_sync_erp] Trigger fired for task_completions id=% TG_OP=%', COALESCE(NEW.id, 'NULL'), TG_OP;

    -- Only attempt propagation when ERP completion flag is true and an ERP value exists
    v_erp := TRIM(COALESCE(NEW.erp_reference_number, ''));
    IF NEW.erp_reference_completed = true AND v_erp IS NOT NULL AND v_erp <> '' THEN
        -- Find the receiving_task that matches this task completion
        SELECT id, receiving_record_id
        INTO v_rt_id, v_receiving_record_id
        FROM receiving_tasks rt
        WHERE rt.task_id = NEW.task_id
          AND rt.assignment_id = NEW.assignment_id
        LIMIT 1;

        IF FOUND THEN
            RAISE NOTICE '[trg_task_completions_sync_erp] Found receiving_task id=% receiving_record_id=% for task_id=% assignment_id=%', v_rt_id, v_receiving_record_id, NEW.task_id, NEW.assignment_id;

            -- Update receiving_tasks.erp_reference_number
            UPDATE receiving_tasks
            SET erp_reference_number = v_erp
            WHERE id = v_rt_id;
            RAISE NOTICE '[trg_task_completions_sync_erp] Updated receiving_tasks.id=% erp=%', v_rt_id, v_erp;

            -- Update receiving_records.erp_purchase_invoice_reference
            UPDATE receiving_records
            SET erp_purchase_invoice_reference = v_erp,
                updated_at = now()
            WHERE id = v_receiving_record_id;
            RAISE NOTICE '[trg_task_completions_sync_erp] Updated receiving_records.id=% erp=%', v_receiving_record_id, v_erp;
        ELSE
            RAISE NOTICE '[trg_task_completions_sync_erp] No receiving_task found for task_id=% assignment_id=% - nothing to update', NEW.task_id, NEW.assignment_id;
        END IF;
    ELSE
        RAISE NOTICE '[trg_task_completions_sync_erp] No ERP to propagate (completed=% erp=%)', NEW.erp_reference_completed, v_erp;
    END IF;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '[trg_task_completions_sync_erp] ERROR: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger that fires after insert or update on task_completions
DROP TRIGGER IF EXISTS trg_task_completions_sync_erp ON task_completions;
CREATE TRIGGER trg_task_completions_sync_erp
AFTER INSERT OR UPDATE OF erp_reference_number, erp_reference_completed ON task_completions
FOR EACH ROW
EXECUTE FUNCTION trg_task_completions_sync_erp();

-- NOTE: The trigger uses RAISE NOTICE output. When running this in Supabase SQL editor
-- you will see the notices in the execution output which helps debug propagation.

-- =============================================
-- COMPREHENSIVE TEST: Trigger Functionality
-- This simulates a real inventory manager task completion with ERP reference
-- =============================================

DO $$
DECLARE
    test_receiving_record_id UUID;
    test_task_id UUID;
    test_assignment_id UUID;
    test_receiving_task_id UUID;
    test_completion_id UUID;
    test_erp_ref TEXT := 'TEST-ERP-' || EXTRACT(EPOCH FROM NOW())::TEXT;
    before_record RECORD;
    after_record RECORD;
BEGIN
    RAISE NOTICE '🧪 TRIGGER TEST: Starting comprehensive trigger test...';
    
    -- Find a receiving record that has receiving_tasks (or create test data)
    SELECT rr.id, rt.id as rt_id, rt.task_id, rt.assignment_id
    INTO test_receiving_record_id, test_receiving_task_id, test_task_id, test_assignment_id
    FROM receiving_records rr
    JOIN receiving_tasks rt ON rr.id = rt.receiving_record_id
    WHERE rt.role_type = 'inventory_manager'
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE '🎯 Using existing receiving_record: % with receiving_task: %', test_receiving_record_id, test_receiving_task_id;
        
        -- Record BEFORE state
        SELECT 
            rr.erp_purchase_invoice_reference as rr_erp,
            rt.erp_reference_number as rt_erp
        INTO before_record
        FROM receiving_records rr
        JOIN receiving_tasks rt ON rr.id = rt.receiving_record_id
        WHERE rr.id = test_receiving_record_id AND rt.id = test_receiving_task_id;
        
        RAISE NOTICE '📋 BEFORE - receiving_records.erp: %, receiving_tasks.erp: %', 
                     before_record.rr_erp, before_record.rt_erp;
        
        -- Check if task_completion already exists
        SELECT id INTO test_completion_id
        FROM task_completions
        WHERE task_id = test_task_id AND assignment_id = test_assignment_id;
        
        IF FOUND THEN
            RAISE NOTICE '⚡ Updating existing task_completion with ERP reference: %', test_erp_ref;
            -- Update existing task completion with ERP reference (this should trigger the function)
            UPDATE task_completions
            SET 
                erp_reference_number = test_erp_ref,
                erp_reference_completed = true
            WHERE id = test_completion_id;
        ELSE
            RAISE NOTICE '⚡ Creating new task_completion with ERP reference: %', test_erp_ref;
            -- Insert a new task completion with ERP reference (this should trigger the function)
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
                (SELECT id FROM users WHERE role = 'admin' LIMIT 1), -- Use any admin user
                now(),
                test_erp_ref,
                true
            );
        END IF;
        
        -- Small delay to ensure trigger has processed
        PERFORM pg_sleep(0.1);
        
        -- Record AFTER state
        SELECT 
            rr.erp_purchase_invoice_reference as rr_erp,
            rt.erp_reference_number as rt_erp
        INTO after_record
        FROM receiving_records rr
        JOIN receiving_tasks rt ON rr.id = rt.receiving_record_id
        WHERE rr.id = test_receiving_record_id AND rt.id = test_receiving_task_id;
        
        RAISE NOTICE '📋 AFTER - receiving_records.erp: %, receiving_tasks.erp: %', 
                     after_record.rr_erp, after_record.rt_erp;
        
        -- Verify trigger worked
        IF after_record.rr_erp = test_erp_ref AND after_record.rt_erp = test_erp_ref THEN
            RAISE NOTICE '✅ TRIGGER SUCCESS: ERP reference % propagated correctly!', test_erp_ref;
        ELSE
            RAISE NOTICE '❌ TRIGGER FAILED: Expected %, got rr:% rt:%', 
                         test_erp_ref, after_record.rr_erp, after_record.rt_erp;
        END IF;
        
        -- Test the status check function with the updated record
        DECLARE
            status_result JSONB;
        BEGIN
            SELECT check_erp_sync_status_for_record(test_receiving_record_id) INTO status_result;
            RAISE NOTICE '📊 Status after trigger: %', status_result;
        END;
        
    ELSE
        RAISE NOTICE '⚠️ No receiving_records with receiving_tasks found for testing';
        RAISE NOTICE 'Create a clearance certificate first to generate receiving_tasks, then re-run this test';
    END IF;
    
END $$;