-- ================================================================
-- Function: authenticate_customer_access_code
-- Category: customer
-- Return Type: json
-- Arguments: p_access_code text
-- Description: Authenticates customer using 6-digit access code
-- ================================================================

CREATE OR REPLACE FUNCTION authenticate_customer_access_code(
    p_access_code text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_customer_record record;
    result json;
BEGIN
    -- Log the incoming access code for debugging
    RAISE NOTICE 'Authenticating access code: %', p_access_code;
    
    -- Validate access code format
    IF p_access_code IS NULL OR p_access_code !~ '^[0-9]{6}$' THEN
        RAISE NOTICE 'Invalid access code format: %', p_access_code;
        RAISE EXCEPTION 'Invalid access code format';
    END IF;
    
    -- Find customer by access code
    SELECT 
        c.id as customer_id,
        c.name as customer_name,
        c.registration_status,
        c.whatsapp_number,
        c.access_code,
        c.last_login_at
    INTO v_customer_record
    FROM public.customers c
    WHERE c.access_code = p_access_code;
    
    -- Log search result
    RAISE NOTICE 'Customer found: %', v_customer_record.customer_id IS NOT NULL;
    
    -- Check if customer exists
    IF v_customer_record.customer_id IS NULL THEN
        RAISE NOTICE 'No customer found with access code: %', p_access_code;
        RAISE EXCEPTION 'Invalid access code';
    END IF;
    
    -- Log customer status
    RAISE NOTICE 'Customer status: %', v_customer_record.registration_status;
    
    -- Check customer status
    IF v_customer_record.registration_status != 'approved' THEN
        RAISE EXCEPTION 'Customer registration not approved';
    END IF;
    
    -- Update last login time
    UPDATE public.customers SET
        last_login_at = now(),
        updated_at = now()
    WHERE id = v_customer_record.customer_id;
    
    -- Return successful authentication
    result := json_build_object(
        'success', true,
        'customer_id', v_customer_record.customer_id,
        'customer_name', v_customer_record.customer_name,
        'whatsapp_number', v_customer_record.whatsapp_number,
        'registration_status', v_customer_record.registration_status,
        'message', 'Authentication successful'
    );
    
    RAISE NOTICE 'Authentication successful for customer: %', v_customer_record.customer_name;
    RETURN result;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Authentication failed with error: %', SQLERRM;
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;