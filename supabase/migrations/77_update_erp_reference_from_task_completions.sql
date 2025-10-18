-- =============================================
-- Update ERP Reference to use task_completions table
-- This migration updates the complete_receiving_task function and related mechanisms
-- to pull ERP reference data from the task_completions table instead of receiving_tasks
-- =============================================

-- First, ensure the receiving_records table has the necessary column
ALTER TABLE public.receiving_records 
ADD COLUMN IF NOT EXISTS erp_purchase_invoice_reference VARCHAR(255);

-- Add updated_at column if it doesn't exist
ALTER TABLE public.receiving_records 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_receiving_records_erp_purchase_invoice_reference 
ON public.receiving_records(erp_purchase_invoice_reference);

CREATE INDEX IF NOT EXISTS idx_receiving_records_updated_at 
ON public.receiving_records(updated_at DESC);

-- =============================================
-- UPDATED complete_receiving_task function to work with task_completions
-- =============================================

CREATE OR REPLACE FUNCTION complete_receiving_task(
    receiving_task_id_param UUID,
    user_id_param UUID,
    erp_reference_param VARCHAR DEFAULT NULL,
    original_bill_file_path_param TEXT DEFAULT NULL,
    completion_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    receiving_task RECORD;
    task_completed BOOLEAN;
    completion_record RECORD;
    response JSONB;
BEGIN
    -- Get the receiving task
    SELECT * INTO receiving_task 
    FROM receiving_tasks 
    WHERE id = receiving_task_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiving task not found: %', receiving_task_id_param;
    END IF;
    
    -- Verify user is assigned to this task
    IF receiving_task.assigned_user_id != user_id_param THEN
        RAISE EXCEPTION 'User not authorized to complete this task';
    END IF;
    
    -- Check if task is already completed
    IF receiving_task.task_completed THEN
        RAISE EXCEPTION 'Task is already completed';
    END IF;
    
    -- Update task with completion data in receiving_tasks
    SELECT update_receiving_task_completion(
        receiving_task_id_param,
        erp_reference_param,
        original_bill_file_path_param IS NOT NULL,
        original_bill_file_path_param
    ) INTO task_completed;
    
    -- Create or update completion record in task_completions table
    IF task_completed THEN
        -- Get user details for completion record
        SELECT 
            u.username,
            COALESCE(he.name, u.username) as display_name,
            u.branch_id
        INTO completion_record
        FROM users u
        LEFT JOIN hr_employees he ON u.employee_id = he.id
        WHERE u.id = user_id_param;
        
        -- Insert completion record into task_completions table
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
            completion_notes,
            completed_at
        ) VALUES (
            receiving_task.task_id,
            receiving_task.assignment_id,
            user_id_param::TEXT,
            completion_record.display_name,
            completion_record.branch_id,
            true, -- task_finished_completed
            original_bill_file_path_param IS NOT NULL, -- photo_uploaded_completed
            erp_reference_param IS NOT NULL AND erp_reference_param != '', -- erp_reference_completed
            erp_reference_param,
            completion_notes,
            now()
        )
        ON CONFLICT (task_id, assignment_id) DO UPDATE SET
            completed_by = EXCLUDED.completed_by,
            completed_by_name = EXCLUDED.completed_by_name,
            completed_by_branch_id = EXCLUDED.completed_by_branch_id,
            task_finished_completed = EXCLUDED.task_finished_completed,
            photo_uploaded_completed = EXCLUDED.photo_uploaded_completed,
            erp_reference_completed = EXCLUDED.erp_reference_completed,
            erp_reference_number = EXCLUDED.erp_reference_number,
            completion_notes = EXCLUDED.completion_notes,
            completed_at = EXCLUDED.completed_at;
    END IF;
    
    -- NEW: If this is an inventory manager task with ERP reference, 
    -- update the receiving_records table with ERP reference from task_completions
    IF receiving_task.role_type = 'inventory_manager' AND erp_reference_param IS NOT NULL AND erp_reference_param != '' THEN
        UPDATE receiving_records 
        SET 
            erp_purchase_invoice_reference = erp_reference_param,
            updated_at = now()
        WHERE id = receiving_task.receiving_record_id;
        
        -- Log the update for audit purposes
        INSERT INTO user_audit_logs (
            user_id,
            action,
            table_name,
            record_id,
            changes,
            created_at
        ) VALUES (
            user_id_param,
            'update_erp_reference_from_task_completion',
            'receiving_records',
            receiving_task.receiving_record_id::TEXT,
            jsonb_build_object(
                'erp_purchase_invoice_reference', erp_reference_param,
                'receiving_task_id', receiving_task_id_param,
                'task_id', receiving_task.task_id,
                'assignment_id', receiving_task.assignment_id,
                'role_type', receiving_task.role_type,
                'source', 'task_completions'
            ),
            now()
        );
        
        RAISE NOTICE 'Updated receiving_records.erp_purchase_invoice_reference = % for receiving_record_id = % from task_completions', 
            erp_reference_param, receiving_task.receiving_record_id;
    END IF;
    
    -- Create completion notification
    IF task_completed THEN
        INSERT INTO notifications (
            title, message, created_by,
            target_type, target_users, type, priority,
            task_id, task_assignment_id,
            metadata
        ) VALUES (
            'Task Completed',
            format('Task "%s" has been completed successfully', receiving_task.role_type),
            user_id_param::TEXT,
            'specific_users', to_jsonb(ARRAY[user_id_param::TEXT]),
            'success', 'low',
            receiving_task.task_id, receiving_task.assignment_id,
            jsonb_build_object(
                'receiving_task_id', receiving_task_id_param,
                'completion_notes', completion_notes,
                'erp_reference_updated', receiving_task.role_type = 'inventory_manager' AND erp_reference_param IS NOT NULL,
                'source_table', 'task_completions'
            )
        );
    END IF;
    
    response := jsonb_build_object(
        'success', true,
        'task_completed', task_completed,
        'receiving_task_id', receiving_task_id_param,
        'completed_at', CASE WHEN task_completed THEN now() ELSE NULL END,
        'erp_reference_updated', receiving_task.role_type = 'inventory_manager' AND erp_reference_param IS NOT NULL AND erp_reference_param != '',
        'task_completions_created', task_completed,
        'requirements_met', jsonb_build_object(
            'erp_reference_provided', erp_reference_param IS NOT NULL,
            'original_bill_uploaded', original_bill_file_path_param IS NOT NULL
        )
    );
    
    RETURN response;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'detail', SQLSTATE
        );
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Create a function to sync ERP references from task_completions to receiving_records
-- =============================================

CREATE OR REPLACE FUNCTION sync_erp_references_from_task_completions()
RETURNS TABLE(
    receiving_record_id UUID,
    erp_reference_updated TEXT,
    sync_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH erp_updates AS (
        UPDATE receiving_records rr
        SET 
            erp_purchase_invoice_reference = tc.erp_reference_number,
            updated_at = now()
        FROM task_completions tc
        JOIN receiving_tasks rt ON tc.task_id = rt.task_id AND tc.assignment_id = rt.assignment_id
        WHERE rt.receiving_record_id = rr.id
        AND rt.role_type = 'inventory_manager'
        AND tc.erp_reference_completed = true
        AND tc.erp_reference_number IS NOT NULL
        AND tc.erp_reference_number != ''
        AND (rr.erp_purchase_invoice_reference IS NULL OR rr.erp_purchase_invoice_reference != tc.erp_reference_number)
        RETURNING rr.id as receiving_record_id, tc.erp_reference_number::TEXT, 'updated'::TEXT as sync_status
    )
    SELECT 
        eu.receiving_record_id,
        eu.erp_reference_number,
        eu.sync_status
    FROM erp_updates eu;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Update the view to show ERP references from both sources
-- =============================================

-- Drop the existing view and recreate it to include task_completions data
DROP VIEW IF EXISTS receiving_records_with_erp;

CREATE VIEW receiving_records_with_erp AS
SELECT 
    rr.*,
    v.vendor_name,
    b.name_en as branch_name,
    u.username as created_by_username,
    COALESCE(he.name, u.username) as created_by_name,
    
    -- ERP reference from receiving_tasks (legacy)
    rt.erp_reference_number as receiving_task_erp_reference,
    rt.task_completed as inventory_manager_task_completed,
    rt.completed_at as inventory_manager_completed_at,
    
    -- ERP reference from task_completions (new)
    tc.erp_reference_number as task_completion_erp_reference,
    tc.erp_reference_completed as task_completion_erp_completed,
    tc.completed_at as task_completion_completed_at,
    tc.completed_by_name as task_completed_by_name,
    
    -- Final ERP reference (prioritize receiving_records column, then task_completions, then receiving_tasks)
    COALESCE(
        rr.erp_purchase_invoice_reference,
        tc.erp_reference_number,
        rt.erp_reference_number
    ) as final_erp_reference
    
FROM receiving_records rr
LEFT JOIN vendors v ON rr.vendor_id = v.erp_vendor_id
LEFT JOIN branches b ON rr.branch_id = b.id
LEFT JOIN users u ON rr.user_id = u.id
LEFT JOIN hr_employees he ON u.employee_id = he.id
LEFT JOIN receiving_tasks rt ON rr.id = rt.receiving_record_id AND rt.role_type = 'inventory_manager'
LEFT JOIN task_completions tc ON rt.task_id = tc.task_id AND rt.assignment_id = tc.assignment_id
ORDER BY rr.created_at DESC;

-- =============================================
-- Create a trigger to automatically sync ERP references
-- =============================================

CREATE OR REPLACE FUNCTION trigger_sync_erp_reference_on_task_completion()
RETURNS TRIGGER AS $$
DECLARE
    receiving_record_id_var UUID;
BEGIN
    -- Only process if this is an ERP reference completion
    IF NEW.erp_reference_completed = true AND NEW.erp_reference_number IS NOT NULL AND NEW.erp_reference_number != '' THEN
        -- Find the receiving record ID through receiving_tasks
        SELECT rt.receiving_record_id INTO receiving_record_id_var
        FROM receiving_tasks rt
        WHERE rt.task_id = NEW.task_id 
        AND rt.assignment_id = NEW.assignment_id
        AND rt.role_type = 'inventory_manager';
        
        -- Update receiving_records if found
        IF receiving_record_id_var IS NOT NULL THEN
            UPDATE receiving_records 
            SET 
                erp_purchase_invoice_reference = NEW.erp_reference_number,
                updated_at = now()
            WHERE id = receiving_record_id_var
            AND (erp_purchase_invoice_reference IS NULL OR erp_purchase_invoice_reference != NEW.erp_reference_number);
            
            RAISE NOTICE 'Auto-synced ERP reference % to receiving_record %', NEW.erp_reference_number, receiving_record_id_var;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
DROP TRIGGER IF EXISTS trigger_sync_erp_on_completion ON task_completions;
CREATE TRIGGER trigger_sync_erp_on_completion
AFTER INSERT OR UPDATE ON task_completions
FOR EACH ROW
EXECUTE FUNCTION trigger_sync_erp_reference_on_task_completion();

-- =============================================
-- Test queries and validation
-- =============================================

-- Check if all necessary columns exist
SELECT 
    table_name, 
    column_name, 
    data_type, 
    is_nullable 
FROM information_schema.columns 
WHERE table_name IN ('receiving_records', 'task_completions')
AND column_name IN ('erp_purchase_invoice_reference', 'erp_reference_number', 'erp_reference_completed')
ORDER BY table_name, column_name;

-- Test the sync function
SELECT * FROM sync_erp_references_from_task_completions() LIMIT 5;

-- Check recent receiving records with ERP references from both sources
SELECT 
    rr.id,
    rr.bill_number,
    rr.erp_purchase_invoice_reference as direct_erp_ref,
    tc.erp_reference_number as task_completion_erp_ref,
    rt.erp_reference_number as receiving_task_erp_ref,
    tc.erp_reference_completed,
    rt.task_completed,
    rr.created_at
FROM receiving_records rr
LEFT JOIN receiving_tasks rt ON rr.id = rt.receiving_record_id AND rt.role_type = 'inventory_manager'
LEFT JOIN task_completions tc ON rt.task_id = tc.task_id AND rt.assignment_id = tc.assignment_id
ORDER BY rr.created_at DESC
LIMIT 10;

-- =============================================
-- Success messages
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '✅ ERP Reference update from task_completions completed successfully!';
    RAISE NOTICE '📊 The receiving_records table now gets ERP references from task_completions';
    RAISE NOTICE '🔄 Auto-sync trigger created to update receiving_records when task_completions are created';
    RAISE NOTICE '📋 Updated view "receiving_records_with_erp" shows data from both sources';
    RAISE NOTICE '🛠️ Use sync_erp_references_from_task_completions() function to manually sync existing data';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 ERP Reference flow:';
    RAISE NOTICE '1. User completes task → task_completions.erp_reference_number';
    RAISE NOTICE '2. Trigger automatically updates → receiving_records.erp_purchase_invoice_reference';
    RAISE NOTICE '3. View shows final ERP reference with priority: receiving_records > task_completions > receiving_tasks';
END $$;