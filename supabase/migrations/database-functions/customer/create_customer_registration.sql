-- ================================================================
-- Function: create_customer_registration
-- Category: customer
-- Return Type: json
-- Arguments: p_name text, p_whatsapp_number text
-- Description: Creates a new customer registration request
-- ================================================================

CREATE OR REPLACE FUNCTION create_customer_registration(
    p_name text,
    p_whatsapp_number text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_customer_id uuid;
    v_admin_user_ids text[];
    v_current_time timestamp with time zone := now();
    result json;
BEGIN
    -- Validate inputs
    IF p_name IS NULL OR trim(p_name) = '' THEN
        RAISE EXCEPTION 'Customer name is required';
    END IF;
    
    IF p_whatsapp_number IS NULL OR trim(p_whatsapp_number) = '' THEN
        RAISE EXCEPTION 'Mobile number is required';
    END IF;
    
    -- Clean WhatsApp number (remove non-digits)
    p_whatsapp_number := regexp_replace(p_whatsapp_number, '[^0-9]', '', 'g');
    
    -- Add country code if not present (assume Saudi +966 for 9-digit numbers)
    IF length(p_whatsapp_number) = 9 THEN
        p_whatsapp_number := '966' || p_whatsapp_number;
    END IF;
    
    -- Check if mobile number already exists (check multiple formats)
    IF EXISTS(
        SELECT 1 FROM public.customers 
        WHERE whatsapp_number = p_whatsapp_number 
           OR whatsapp_number = '+' || p_whatsapp_number
           OR regexp_replace(whatsapp_number, '[^0-9]', '', 'g') = p_whatsapp_number
    ) THEN
        RAISE EXCEPTION 'Mobile number already registered';
    END IF;
    
    -- Create customer record only (no user record needed)
    INSERT INTO public.customers (
        name,
        whatsapp_number,
        registration_status,
        created_at,
        updated_at
    ) VALUES (
        trim(p_name),
        '+' || p_whatsapp_number,
        'pending',
        v_current_time,
        v_current_time
    ) RETURNING id INTO v_customer_id;
    
    -- Create notification for admin users (same pattern as account recovery)
    BEGIN
        -- Get all admin user IDs
        SELECT array_agg(id::text) INTO v_admin_user_ids
        FROM public.users 
        WHERE role_type IN ('Admin', 'Master Admin') 
        AND status = 'active';
        
        -- Create notification for specific admin users
        IF v_admin_user_ids IS NOT NULL AND array_length(v_admin_user_ids, 1) > 0 THEN
            INSERT INTO public.notifications (
                title,
                message,
                type,
                priority,
                target_type,
                target_users,
                status,
                created_by,
                created_by_name,
                created_by_role,
                metadata
            ) VALUES (
                'New Customer Registration',
                'New customer registration request from ' || trim(p_name) || ' (WhatsApp: +' || p_whatsapp_number || ')',
                'info',
                'high',
                'specific_users',
                array_to_json(v_admin_user_ids)::jsonb,
                'published',
                'b658eca1-3cc1-48b2-bd3c-33b81fab5a0f',
                'System',
                'Master Admin',
                json_build_object(
                    'customer_id', v_customer_id,
                    'customer_name', trim(p_name),
                    'whatsapp_number', '+' || p_whatsapp_number,
                    'registration_status', 'pending',
                    'submitted_at', v_current_time
                )
            );
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            -- Don't fail the whole registration if notification fails
            RAISE NOTICE 'Failed to create notification: %', SQLERRM;
    END;
    
    -- Return result
    result := json_build_object(
        'success', true,
        'customer_id', v_customer_id,
        'customer_name', trim(p_name),
        'whatsapp_number', '+' || p_whatsapp_number,
        'message', 'Registration request submitted successfully. You will receive your login credentials via WhatsApp once approved.'
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_customer_registration(text, text) TO anon;
GRANT EXECUTE ON FUNCTION create_customer_registration(text, text) TO authenticated;