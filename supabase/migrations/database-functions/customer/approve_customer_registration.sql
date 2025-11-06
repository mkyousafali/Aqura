-- ================================================================
-- Function: approve_customer_registration
-- Category: customer
-- Return Type: json
-- Arguments: p_customer_id uuid, p_approved_by uuid, p_notes text
-- Description: Approves customer registration and generates access code
-- ================================================================

CREATE OR REPLACE FUNCTION approve_customer_registration(
    p_customer_id uuid,
    p_approved_by uuid,
    p_notes text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_access_code text;
    v_customer_name text;
    v_whatsapp_number text;
    result json;
BEGIN
    -- Validate customer exists and is pending
    SELECT c.name, c.whatsapp_number
    INTO v_customer_name, v_whatsapp_number
    FROM public.customers c
    WHERE c.id = p_customer_id AND c.registration_status = 'pending';
    
    IF v_customer_name IS NULL THEN
        RAISE EXCEPTION 'Customer not found or not in pending status';
    END IF;
    
    -- Generate unique access code
    SELECT generate_unique_customer_access_code() INTO v_access_code;
    
    -- Update customer record
    UPDATE public.customers SET
        registration_status = 'approved',
        access_code = v_access_code,
        approved_by = p_approved_by,
        approved_at = now(),
        access_code_generated_at = now(),
        registration_notes = COALESCE(p_notes, registration_notes),
        updated_at = now()
    WHERE id = p_customer_id;
    
    -- Create approval notification
    INSERT INTO public.notifications (
        title,
        message,
        type,
        priority,
        metadata,
        deleted_at
    ) VALUES (
        'Customer Registration Approved',
        'Customer ' || v_customer_name || ' has been approved with access code ' || v_access_code,
        'customer_approved',
        'high',
        json_build_object(
            'customer_id', p_customer_id,
            'access_code', v_access_code,
            'approved_by', p_approved_by,
            'customer_name', v_customer_name,
            'whatsapp_number', v_whatsapp_number
        ),
        NULL
    );
    
    -- Return result
    result := json_build_object(
        'success', true,
        'access_code', v_access_code,
        'customer_name', v_customer_name,
        'whatsapp_number', v_whatsapp_number,
        'message', 'Customer registration approved successfully'
    );
    
    RETURN result;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;