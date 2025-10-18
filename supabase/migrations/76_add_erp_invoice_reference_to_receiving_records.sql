-- =============================================
-- Add ERP Purchase Invoice Reference to Receiving Records
-- This column will store the ERP reference number entered by inventory managers
-- when they complete their receiving tasks
-- =============================================

-- Add the ERP purchase invoice reference column
ALTER TABLE public.receiving_records 
ADD COLUMN IF NOT EXISTS erp_purchase_invoice_reference VARCHAR(255);

-- Add updated_at column for tracking changes
ALTER TABLE public.receiving_records 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_receiving_records_erp_purchase_invoice_reference 
ON public.receiving_records(erp_purchase_invoice_reference);

-- Add index for updated_at
CREATE INDEX IF NOT EXISTS idx_receiving_records_updated_at 
ON public.receiving_records(updated_at DESC);

-- Add comments to document the columns
COMMENT ON COLUMN public.receiving_records.erp_purchase_invoice_reference 
IS 'ERP purchase invoice reference number entered by inventory manager when completing receiving task';

COMMENT ON COLUMN public.receiving_records.updated_at 
IS 'Timestamp when the record was last updated';

-- Create trigger to automatically update updated_at
CREATE OR REPLACE FUNCTION update_receiving_records_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_receiving_records_updated_at ON receiving_records;
CREATE TRIGGER trigger_update_receiving_records_updated_at 
BEFORE UPDATE ON receiving_records 
FOR EACH ROW 
EXECUTE FUNCTION update_receiving_records_updated_at();

-- =============================================
-- Update the complete_receiving_task function to also update receiving_records
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
    
    -- If this is an inventory manager task with ERP reference, 
    -- also update the receiving_records table
    IF receiving_task.role_type = 'inventory_manager' AND erp_reference_param IS NOT NULL THEN
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
    END IF;
    
    -- Create task completion record
    INSERT INTO task_completions (
        task_id,
        assignment_id,
        completed_by,
        completed_by_name,
        completed_by_branch_id,
        task_finished_completed,
        photo_uploaded_completed,
        completion_photo_url,
        erp_reference_completed,
        erp_reference_number,
        completion_notes,
        completed_at
    ) VALUES (
        receiving_task.task_id,
        receiving_task.assignment_id,
        user_id_param,
        (SELECT COALESCE(hr_employees.name, users.username) FROM users 
         LEFT JOIN hr_employees ON users.employee_id = hr_employees.id 
         WHERE users.id = user_id_param),
        (SELECT branch_id FROM users WHERE id = user_id_param),
        true, -- task_finished_completed
        original_bill_file_path_param IS NOT NULL, -- photo_uploaded_completed
        original_bill_file_path_param, -- completion_photo_url
        erp_reference_param IS NOT NULL, -- erp_reference_completed
        erp_reference_param, -- erp_reference_number
        completion_notes,
        now()
    );
    
    response := jsonb_build_object(
        'success', true,
        'receiving_task_id', receiving_task_id_param,
        'task_completed', task_completed,
        'erp_reference_updated', receiving_task.role_type = 'inventory_manager' AND erp_reference_param IS NOT NULL,
        'completed_at', now()
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
-- Create a view to easily see receiving records with ERP references
-- =============================================

CREATE OR REPLACE VIEW receiving_records_with_erp AS
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

-- Add comment to the view
COMMENT ON VIEW receiving_records_with_erp 
IS 'View showing receiving records with ERP reference information from inventory manager tasks';

-- Grant appropriate permissions
GRANT SELECT ON receiving_records_with_erp TO authenticated;
GRANT SELECT ON receiving_records_with_erp TO service_role;