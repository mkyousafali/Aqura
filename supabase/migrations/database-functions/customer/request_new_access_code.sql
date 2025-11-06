-- ================================================================
-- Function: request_new_access_code
-- Category: customer
-- Return Type: json
-- Arguments: p_whatsapp_number text
-- Description: Allows customer to request account recovery (username + access code) if they forgot their credentials
-- ================================================================

CREATE OR REPLACE FUNCTION request_new_access_code(
    p_whatsapp_number text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_customer_id uuid;
    v_customer_name text;
    v_current_time timestamp with time zone := now();
    v_request_id uuid;
    result json;
BEGIN
    -- Validate input
    IF p_whatsapp_number IS NULL OR trim(p_whatsapp_number) = '' THEN
        RETURN json_build_object(
            'success', false,
            'error', 'WhatsApp number is required'
        );
    END IF;
    
    -- Clean WhatsApp number (remove non-digits)
    p_whatsapp_number := regexp_replace(p_whatsapp_number, '[^0-9]', '', 'g');
    
    -- Add country code if not present (assume Saudi +966 for 9-digit numbers)
    IF length(p_whatsapp_number) = 9 THEN
        p_whatsapp_number := '966' || p_whatsapp_number;
    END IF;
    
    -- Find customer by WhatsApp number (check both formats: with and without +)
    SELECT 
        id,
        name
    INTO 
        v_customer_id,
        v_customer_name
    FROM public.customers
    WHERE (whatsapp_number = p_whatsapp_number 
           OR whatsapp_number = '+' || p_whatsapp_number
           OR regexp_replace(whatsapp_number, '[^0-9]', '', 'g') = p_whatsapp_number)
    AND registration_status = 'approved'
    LIMIT 1;
    
    -- Check if customer exists
    IF v_customer_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'No approved customer account found with this WhatsApp number. Please contact support if you believe this is an error.'
        );
    END IF;
    
    -- Create recovery request record
    BEGIN
        INSERT INTO public.customer_recovery_requests (
            customer_id,
            whatsapp_number,
            customer_name,
            request_type,
            verification_status
        ) VALUES (
            v_customer_id,
            p_whatsapp_number,
            v_customer_name,
            'account_recovery',
            'pending'
        ) RETURNING id INTO v_request_id;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN json_build_object(
                'success', false,
                'error', 'Failed to create recovery request: ' || SQLERRM
            );
    END;

    -- Create notification using Supabase RPC to call the app's notification service
    BEGIN
        -- Get all admin user IDs
        DECLARE
            v_admin_user_ids text[];
        BEGIN
            SELECT array_agg(id::text) INTO v_admin_user_ids
            FROM public.users 
            WHERE role_type IN ('Admin', 'Master Admin') 
            AND status = 'active';
            
            -- Create notification for specific admin users
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
                'Account Recovery Request',
                'Customer ' || v_customer_name || ' has requested account recovery via WhatsApp: +' || p_whatsapp_number,
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
                    'customer_name', v_customer_name,
                    'whatsapp_number', '+' || p_whatsapp_number,
                    'request_id', v_request_id,
                    'verification_required', true,
                    'requested_at', v_current_time
                )
            );
        END;
    EXCEPTION
        WHEN OTHERS THEN
            -- Don't fail the whole recovery if notification fails
            RAISE NOTICE 'Failed to create notification: %', SQLERRM;
    END;

    result := json_build_object(
        'success', true,
        'message', 'Account recovery request submitted successfully. An administrator will contact you soon for verification.',
        'request_id', v_request_id,
        'customer_name', v_customer_name,
        'whatsapp_number', p_whatsapp_number
    );
    
    RETURN result;EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Failed to process account recovery request: ' || SQLERRM
        );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION request_new_access_code(text) TO anon;
GRANT EXECUTE ON FUNCTION request_new_access_code(text) TO authenticated;