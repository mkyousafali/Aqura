-- ================================================================
-- Function: generate_new_customer_access_code
-- Category: customer
-- Return Type: json
-- Arguments: p_customer_id uuid, p_admin_user_id uuid, p_notes text
-- Description: Generates a new access code for an existing customer (admin function)
-- ================================================================

CREATE OR REPLACE FUNCTION generate_new_customer_access_code(
    p_customer_id uuid,
    p_admin_user_id uuid,
    p_notes text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_access_code text;
    v_customer_name text;
    v_whatsapp_number text;
    v_old_access_code text;
    v_admin_name text;
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
    
    -- Get customer details
    SELECT 
        c.access_code,
        c.whatsapp_number,
        c.name
    INTO 
        v_old_access_code,
        v_whatsapp_number,
        v_customer_name
    FROM public.customers c
    WHERE c.id = p_customer_id;
    
    IF v_customer_name IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Customer not found'
        );
    END IF;
    
    -- Generate new unique access code
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
    WHERE id = p_customer_id;
    
    -- Log the access code change in notifications
    INSERT INTO public.notifications (
        title,
        message,
        type,
        priority,
        metadata,
        deleted_at
    ) VALUES (
        'Customer Access Code Regenerated',
        'Access code regenerated for customer: ' || v_customer_name || ' by admin: ' || v_admin_name,
        'customer_access_code_change',
        'medium',
        json_build_object(
            'customer_id', p_customer_id,
            'customer_name', v_customer_name,
            'old_access_code', v_old_access_code,
            'new_access_code', v_new_access_code,
            'generated_by', v_admin_name,
            'generated_at', v_current_time,
            'notes', p_notes
        ),
        NULL
    );
    
    -- Create notification for customer
    INSERT INTO public.notifications (
        title,
        message,
        type,
        priority,
        metadata,
        deleted_at
    ) VALUES (
        'New Access Code Generated',
        'Your access code has been updated by an administrator.',
        'customer_notification',
        'high',
        json_build_object(
            'customer_id', p_customer_id,
            'new_access_code', v_new_access_code,
            'generated_by', v_admin_name,
            'generated_at', v_current_time,
            'notes', p_notes
        ),
        NULL
    );
    
    -- Log admin activity
    INSERT INTO public.user_activity_logs (
        user_id,
        activity_type,
        description,
        metadata,
        created_at
    ) VALUES (
        p_admin_user_id,
        'customer_access_code_regenerated',
        'Generated new access code for customer: ' || v_customer_name,
        json_build_object(
            'customer_id', p_customer_id,
            'customer_name', v_customer_name,
            'old_access_code', v_old_access_code,
            'new_access_code', v_new_access_code,
            'notes', p_notes
        ),
        v_current_time
    );
    
    result := json_build_object(
        'success', true,
        'message', 'New access code generated successfully',
        'customer_id', p_customer_id,
        'customer_name', v_customer_name,
        'whatsapp_number', v_whatsapp_number,
        'new_access_code', v_new_access_code,
        'old_access_code', v_old_access_code,
        'generated_by', v_admin_name,
        'generated_at', v_current_time
    );
    
    RETURN result;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Failed to generate new access code: ' || SQLERRM
        );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION generate_new_customer_access_code(uuid, uuid, text) TO authenticated;