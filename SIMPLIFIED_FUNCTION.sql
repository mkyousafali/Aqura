-- SIMPLIFIED FUNCTION: Only create inventory manager task for testing
-- This will help us isolate the exact issue

CREATE OR REPLACE FUNCTION generate_clearance_certificate_tasks(
    receiving_record_id_param UUID,
    clearance_certificate_url_param TEXT,
    created_by_user_id TEXT,
    created_by_name TEXT DEFAULT NULL,
    created_by_role TEXT DEFAULT NULL
)
RETURNS TABLE(
    task_count INTEGER,
    notification_count INTEGER,
    task_ids UUID[],
    assignment_ids UUID[]
) AS $$
DECLARE
    receiving_record RECORD;
    vendor_record RECORD;
    task_id UUID;
    assignment_id UUID;
    deadline_datetime TIMESTAMPTZ;
    task_description TEXT;
BEGIN
    RAISE NOTICE 'Starting task generation for receiving record: %', receiving_record_id_param;
    
    deadline_datetime := now() + INTERVAL '24 hours';
    
    -- Get receiving record
    SELECT * INTO receiving_record FROM receiving_records WHERE id = receiving_record_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiving record not found: %', receiving_record_id_param;
    END IF;
    
    RAISE NOTICE 'Found receiving record. Branch ID: %, Type: %', receiving_record.branch_id, pg_typeof(receiving_record.branch_id);
    
    -- Get vendor details
    SELECT * INTO vendor_record FROM vendors WHERE erp_vendor_id = receiving_record.vendor_id;
    
    task_description := format('Vendor: %s, Bill Date: %s, Received by: %s',
        COALESCE(vendor_record.vendor_name, 'Unknown Vendor'),
        receiving_record.bill_date::TEXT,
        COALESCE(created_by_name, 'Unknown User')
    );
    
    RAISE NOTICE 'Task description: %', task_description;
    
    -- Only create inventory manager task for testing
    IF receiving_record.inventory_manager_user_id IS NOT NULL THEN
        RAISE NOTICE 'Creating task for inventory manager: %', receiving_record.inventory_manager_user_id;
        
        -- Try to create the task with explicit parameter casting
        BEGIN
            SELECT create_task(
                'New Delivery Arrived – Enter into Purchase ERP and Upload Original Bill'::TEXT,
                task_description::TEXT,
                created_by_user_id::TEXT,
                COALESCE(created_by_name, '')::TEXT,
                COALESCE(created_by_role, '')::TEXT,
                'high'::TEXT,
                'receiving_delivery'::VARCHAR,
                deadline_datetime::DATE,
                deadline_datetime::TIME,
                true::BOOLEAN,                      -- require_task_finished_param
                false::BOOLEAN,                     -- require_photo_upload_param
                false::BOOLEAN,                     -- require_erp_reference_param (NO ERP!)
                false::BOOLEAN,                     -- can_escalate_param
                false::BOOLEAN,                     -- can_reassign_param
                NULL::INTERVAL,                     -- estimated_duration_param
                NULL::BIGINT,                       -- department_id_param
                receiving_record.branch_id::BIGINT, -- branch_id_param (CAST TO BIGINT)
                NULL::UUID,                         -- project_id_param
                NULL::UUID,                         -- parent_task_id_param
                ARRAY['delivery', 'erp_entry', 'original_bill']::TEXT[], -- tags_param
                jsonb_build_object(
                    'receiving_record_id', receiving_record_id_param,
                    'role_type', 'inventory_manager',
                    'clearance_certificate_url', clearance_certificate_url_param
                )::JSONB,                           -- metadata_param
                false::BOOLEAN                      -- approval_required_param
            ) INTO task_id;
            
            RAISE NOTICE 'Task created successfully with ID: %', task_id;
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'ERROR creating task: %', SQLERRM;
            RAISE EXCEPTION 'Failed to create task: %', SQLERRM;
        END;
        
        -- If we get here, the task was created successfully
        RETURN QUERY SELECT 1, 0, ARRAY[task_id], ARRAY[NULL::UUID];
    ELSE
        RAISE NOTICE 'No inventory manager assigned to this receiving record';
        RETURN QUERY SELECT 0, 0, ARRAY[]::UUID[], ARRAY[]::UUID[];
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Function error: %', SQLERRM;
    RAISE EXCEPTION 'Function failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Test message
SELECT 'Simplified function created for debugging. Try generating tasks now.' as result;