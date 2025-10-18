-- Test just the inventory manager task creation part
-- Extract from the migration to test if our types are correct

CREATE OR REPLACE FUNCTION test_inventory_manager_task(
    receiving_record_id_param UUID,
    clearance_certificate_url_param TEXT,
    created_by_user_id TEXT,
    created_by_name TEXT DEFAULT NULL,
    created_by_role TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    receiving_record RECORD;
    vendor_record RECORD;
    task_id UUID;
    deadline_datetime TIMESTAMPTZ;
    task_description TEXT;
BEGIN
    -- Set deadline to 24 hours from now
    deadline_datetime := now() + INTERVAL '24 hours';
    
    -- Get receiving record details
    SELECT * INTO receiving_record FROM receiving_records WHERE id = receiving_record_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiving record not found: %', receiving_record_id_param;
    END IF;
    
    -- Get vendor details
    SELECT * INTO vendor_record FROM vendors WHERE erp_vendor_id = receiving_record.vendor_id;
    
    -- Task description template
    task_description := format('Vendor: %s, Bill Date: %s, Received by: %s',
        COALESCE(vendor_record.vendor_name, 'Unknown Vendor'),
        receiving_record.bill_date::TEXT,
        COALESCE(created_by_name, 'Unknown User')
    );
    
    -- Test the create_task call with exact types
    SELECT create_task(
        'New Delivery Arrived – Enter into Purchase ERP and Upload Original Bill'::TEXT,
        task_description::TEXT,
        created_by_user_id::TEXT,
        created_by_name::TEXT,
        created_by_role::TEXT,
        'high'::TEXT,
        'receiving_delivery'::VARCHAR,
        (deadline_datetime)::DATE,
        (deadline_datetime)::TIME,
        true::BOOLEAN,
        false::BOOLEAN,
        false::BOOLEAN, -- require_erp_reference = false (NO ERP REQUIRED)
        false::BOOLEAN,
        false::BOOLEAN,
        NULL::INTERVAL,
        NULL::BIGINT,
        receiving_record.branch_id::BIGINT, -- Proper type casting
        NULL::UUID,
        NULL::UUID,
        ARRAY['delivery', 'erp_entry', 'original_bill']::TEXT[],
        jsonb_build_object(
            'receiving_record_id', receiving_record_id_param,
            'role_type', 'inventory_manager',
            'clearance_certificate_url', clearance_certificate_url_param
        )::JSONB,
        false::BOOLEAN
    ) INTO task_id;
    
    RAISE NOTICE 'Task created successfully with ID: %', task_id;
    RETURN task_id;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error creating task: %', SQLERRM;
    RAISE EXCEPTION 'Test failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;