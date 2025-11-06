-- ================================================================
-- Function: process_customer_recovery
-- Category: customer
-- Return Type: json
-- Arguments: p_request_id uuid, p_admin_user_id uuid, p_action text, p_notes text
-- Description: Admin function to process customer recovery requests (approve/reject)
-- ================================================================

CREATE OR REPLACE FUNCTION process_customer_recovery(
    p_request_id uuid,
    p_admin_user_id uuid,
    p_action text, -- 'approve' or 'reject'
    p_notes text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request_record record;
    v_admin_name text;
    v_new_access_code text;
    v_current_time timestamp with time zone := now();
    result json;
BEGIN
    -- Validate admin user
    SELECT username INTO v_admin_name
    FROM public.users
    WHERE id = p_admin_user_id
    AND status = 'active';
    
    IF v_admin_name IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Invalid admin user'
        );
    END IF;
    
    -- Validate action
    IF p_action NOT IN ('approve', 'reject') THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Action must be either "approve" or "reject"'
        );
    END IF;
    
    -- Get recovery request details
    SELECT 
        r.id,
        r.customer_id,
        r.customer_name,
        r.whatsapp_number,
        r.verification_status,
        r.request_type
    INTO v_request_record
    FROM public.customer_recovery_requests r
    WHERE r.id = p_request_id
    AND r.verification_status = 'pending';
    
    IF v_request_record.id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Recovery request not found or already processed'
        );
    END IF;
    
    IF p_action = 'approve' THEN
        -- Generate new access code
        v_new_access_code := generate_unique_customer_access_code();
        
        IF v_new_access_code IS NULL THEN
            RETURN json_build_object(
                'success', false,
                'error', 'Failed to generate unique access code'
            );
        END IF;
        
        -- Update customer with new access code
        UPDATE public.customers
        SET 
            access_code = v_new_access_code,
            access_code_generated_at = v_current_time,
            updated_at = v_current_time
        WHERE id = v_request_record.customer_id;
        
        -- Update recovery request status
        UPDATE public.customer_recovery_requests
        SET 
            verification_status = 'processed',
            processed_by = p_admin_user_id,
            processed_at = v_current_time,
            verification_notes = p_notes
        WHERE id = p_request_id;
        
        -- Create success notification
        INSERT INTO public.notifications (
            title,
            message,
            type,
            priority,
            metadata,
            deleted_at
        ) VALUES (
            'Customer Recovery Approved',
            'Recovery request for ' || v_request_record.customer_name || ' has been approved by ' || v_admin_name,
            'customer_recovery_approved',
            'high',
            json_build_object(
                'customer_id', v_request_record.customer_id,
                'customer_name', v_request_record.customer_name,
                'whatsapp_number', v_request_record.whatsapp_number,
                'new_access_code', v_new_access_code,
                'processed_by', v_admin_name,
                'processed_at', v_current_time,
                'request_id', p_request_id,
                'notes', p_notes
            ),
            NULL
        );
        
        result := json_build_object(
            'success', true,
            'message', 'Customer recovery approved successfully',
            'customer_name', v_request_record.customer_name,
            'whatsapp_number', v_request_record.whatsapp_number,
            'new_access_code', v_new_access_code,
            'processed_by', v_admin_name,
            'processed_at', v_current_time
        );
        
    ELSE -- p_action = 'reject'
        -- Update recovery request status
        UPDATE public.customer_recovery_requests
        SET 
            verification_status = 'rejected',
            processed_by = p_admin_user_id,
            processed_at = v_current_time,
            verification_notes = p_notes
        WHERE id = p_request_id;
        
        -- Create rejection notification
        INSERT INTO public.notifications (
            title,
            message,
            type,
            priority,
            metadata,
            deleted_at
        ) VALUES (
            'Customer Recovery Rejected',
            'Recovery request for ' || v_request_record.customer_name || ' has been rejected by ' || v_admin_name,
            'customer_recovery_rejected',
            'medium',
            json_build_object(
                'customer_id', v_request_record.customer_id,
                'customer_name', v_request_record.customer_name,
                'whatsapp_number', v_request_record.whatsapp_number,
                'processed_by', v_admin_name,
                'processed_at', v_current_time,
                'request_id', p_request_id,
                'notes', p_notes
            ),
            NULL
        );
        
        result := json_build_object(
            'success', true,
            'message', 'Customer recovery request rejected',
            'customer_name', v_request_record.customer_name,
            'whatsapp_number', v_request_record.whatsapp_number,
            'processed_by', v_admin_name,
            'processed_at', v_current_time,
            'reason', p_notes
        );
    END IF;
    
    -- Log admin activity
    INSERT INTO public.user_activity_logs (
        user_id,
        activity_type,
        description,
        metadata,
        created_at
    ) VALUES (
        p_admin_user_id,
        'customer_recovery_' || p_action,
        p_action || 'ed customer recovery request for: ' || v_request_record.customer_name,
        json_build_object(
            'customer_id', v_request_record.customer_id,
            'customer_name', v_request_record.customer_name,
            'whatsapp_number', v_request_record.whatsapp_number,
            'request_id', p_request_id,
            'new_access_code', CASE WHEN p_action = 'approve' THEN v_new_access_code ELSE NULL END,
            'notes', p_notes
        ),
        v_current_time
    );
    
    RETURN result;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Failed to process customer recovery: ' || SQLERRM
        );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION process_customer_recovery(uuid, uuid, text, text) TO authenticated;