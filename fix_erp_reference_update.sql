-- =============================================
-- Fix ERP Reference Update Issue
-- This script ensures that when inventory managers complete their tasks with ERP references,
-- the ERP reference is also stored in the receiving_records table
-- =============================================

-- First, let's make sure the column exists
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

-- Create trigger function if it doesn't exist
CREATE OR REPLACE FUNCTION update_receiving_records_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger if it doesn't exist
DROP TRIGGER IF EXISTS trigger_update_receiving_records_updated_at ON receiving_records;
CREATE TRIGGER trigger_update_receiving_records_updated_at 
BEFORE UPDATE ON receiving_records 
FOR EACH ROW 
EXECUTE FUNCTION update_receiving_records_updated_at();

-- =============================================
-- REPLACE the complete_receiving_task function to include ERP reference update
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
    
    -- Update task with completion data
    SELECT update_receiving_task_completion(
        receiving_task_id_param,
        erp_reference_param,
        original_bill_file_path_param IS NOT NULL,
        original_bill_file_path_param
    ) INTO task_completed;
    
    -- NEW: If this is an inventory manager task with ERP reference, 
    -- also update the receiving_records table
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
            'update_erp_reference',
            'receiving_records',
            receiving_task.receiving_record_id::TEXT,
            jsonb_build_object(
                'erp_purchase_invoice_reference', erp_reference_param,
                'receiving_task_id', receiving_task_id_param,
                'role_type', receiving_task.role_type
            ),
            now()
        );
        
        RAISE NOTICE 'Updated receiving_records.erp_purchase_invoice_reference = % for receiving_record_id = %', 
            erp_reference_param, receiving_task.receiving_record_id;
    END IF;
    
    -- If task was successfully completed, add completion notes if column exists
    IF task_completed THEN
        -- Try to update completion notes, but don't fail if column doesn't exist
        BEGIN
            UPDATE task_assignments 
            SET completion_notes = completion_notes
            WHERE id = receiving_task.assignment_id;
        EXCEPTION
            WHEN undefined_column THEN
                -- Ignore error if completion_notes column doesn't exist
                NULL;
        END;
        
        -- Create completion notification
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
                'erp_reference_updated', receiving_task.role_type = 'inventory_manager' AND erp_reference_param IS NOT NULL
            )
        );
    END IF;
    
    response := jsonb_build_object(
        'success', true,
        'task_completed', task_completed,
        'receiving_task_id', receiving_task_id_param,
        'completed_at', CASE WHEN task_completed THEN now() ELSE NULL END,
        'erp_reference_updated', receiving_task.role_type = 'inventory_manager' AND erp_reference_param IS NOT NULL AND erp_reference_param != '',
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
            'error', SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Update the view to show ERP references correctly
-- =============================================

-- Drop the existing view and recreate it to avoid column name conflicts
DROP VIEW IF EXISTS receiving_records_with_erp;

CREATE VIEW receiving_records_with_erp AS
SELECT 
    rr.*,
    v.vendor_name,
    b.name_en as branch_name,
    u.username as created_by_username,
    COALESCE(he.name, u.username) as created_by_name,
    rt.erp_reference_number as inventory_manager_erp_reference,
    rt.task_completed as inventory_manager_task_completed,
    rt.completed_at as inventory_manager_completed_at
FROM receiving_records rr
LEFT JOIN vendors v ON rr.vendor_id = v.erp_vendor_id
LEFT JOIN branches b ON rr.branch_id = b.id
LEFT JOIN users u ON rr.user_id = u.id
LEFT JOIN hr_employees he ON u.employee_id = he.id
LEFT JOIN receiving_tasks rt ON rr.id = rt.receiving_record_id AND rt.role_type = 'inventory_manager'
ORDER BY rr.created_at DESC;

-- =============================================
-- Test query to check if everything is working
-- =============================================

-- Check if the column exists
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'receiving_records' 
AND column_name = 'erp_purchase_invoice_reference';

-- Check recent receiving records with ERP references
SELECT 
    rr.id,
    rr.bill_number,
    rr.erp_purchase_invoice_reference,
    rt.erp_reference_number as task_erp_reference,
    rt.role_type,
    rt.task_completed,
    rr.created_at
FROM receiving_records rr
LEFT JOIN receiving_tasks rt ON rr.id = rt.receiving_record_id AND rt.role_type = 'inventory_manager'
ORDER BY rr.created_at DESC
LIMIT 10;

-- Show function definition to verify it was updated
SELECT routine_name, routine_definition 
FROM information_schema.routines 
WHERE routine_name = 'complete_receiving_task' 
AND routine_type = 'FUNCTION';

RAISE NOTICE 'ERP Reference update fix completed successfully!';
RAISE NOTICE 'The receiving_records table now has erp_purchase_invoice_reference column';
RAISE NOTICE 'The complete_receiving_task function has been updated to handle ERP reference updates';
RAISE NOTICE 'When inventory managers complete tasks with ERP references, they will be stored in both:';
RAISE NOTICE '1. receiving_tasks.erp_reference_number (existing)';
RAISE NOTICE '2. receiving_records.erp_purchase_invoice_reference (new)';