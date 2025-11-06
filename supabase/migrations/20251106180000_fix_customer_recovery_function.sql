-- Fix customer recovery functions to use correct notification system

-- Drop and recreate request_new_access_code function
DROP FUNCTION IF EXISTS public.request_new_access_code(text);

-- ================================================================
-- Function: request_new_access_code
-- Category: customer
-- Return Type: json
-- Arguments: p_whatsapp_number text
-- Description: Allows customer to request account recovery (access code) if they forgot their credentials
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
    v_access_code text;
    v_current_time timestamp with time zone := now();
    v_notification_id uuid;
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
    
    -- Find customer by WhatsApp number
    SELECT 
        c.id,
        c.name,
        c.access_code
    INTO 
        v_customer_id,
        v_customer_name,
        v_access_code
    FROM public.customers c
    WHERE (c.whatsapp_number = p_whatsapp_number OR c.whatsapp_number = '+' || p_whatsapp_number)
    AND c.registration_status = 'approved';
    
    -- Check if customer exists
    IF v_customer_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'No approved customer account found with this WhatsApp number. Please contact support if you believe this is an error.'
        );
    END IF;
    
    -- Create notification for admin using the same pattern as customer registration
    INSERT INTO public.notifications (
        title,
        message,
        type,
        priority,
        target_type,
        created_by,
        created_by_name,
        status,
        metadata
    ) VALUES (
        'Customer Access Code Recovery Request',
        'Customer ' || v_customer_name || ' (WhatsApp: ' || p_whatsapp_number || ') has requested their access code. Please verify their identity via WhatsApp before sharing the access code: ' || v_access_code,
        'account_recovery_request',
        'high',
        'all_admins',
        'system',
        'System',
        'published',
        json_build_object(
            'whatsapp_number', p_whatsapp_number,
            'customer_name', v_customer_name,
            'access_code', v_access_code,
            'request_time', v_current_time,
            'customer_id', v_customer_id,
            'request_type', 'account_recovery',
            'verification_required', true,
            'action_required', 'verify_identity_and_share_access_code'
        )
    ) RETURNING id INTO v_notification_id;
    
    -- Create notification recipients for all admin users (same pattern as customer registration)
    INSERT INTO public.notification_recipients (notification_id, user_id, role)
    SELECT 
        v_notification_id, 
        u.id, 
        'admin'
    FROM public.users u 
    WHERE u.username LIKE '%admin%' 
       OR u.username = 'admin'
       OR u.username = 'master'
       OR u.username = 'yousafali'  -- Add specific known admin usernames
    ON CONFLICT DO NOTHING;
    
    -- Also try to create a customer_notifications entry if the table exists
    -- This will allow the CustomerRegistrationManager to pick up the request
    BEGIN
        INSERT INTO public.customer_notifications (
            customer_id,
            type,
            title,
            message,
            metadata,
            created_at
        ) VALUES (
            v_customer_id,
            'account_recovery_request',
            'Access Code Recovery Request',
            'Customer ' || v_customer_name || ' (WhatsApp: ' || p_whatsapp_number || ') has requested their access code.',
            json_build_object(
                'whatsapp_number', p_whatsapp_number,
                'customer_name', v_customer_name,
                'access_code', v_access_code,
                'request_time', v_current_time,
                'customer_id', v_customer_id,
                'request_type', 'account_recovery',
                'verification_required', true,
                'action_required', 'verify_identity_and_share_access_code'
            ),
            v_current_time
        );
    EXCEPTION
        WHEN undefined_table THEN
            -- customer_notifications table doesn't exist, ignore
            NULL;
    END;
    
    result := json_build_object(
        'success', true,
        'message', 'Access code recovery request submitted successfully. An admin will verify your identity and send your access code via WhatsApp shortly.',
        'customer_id', v_customer_id,
        'customer_name', v_customer_name,
        'access_code', v_access_code
    );
    
    RETURN result;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Failed to process request: ' || SQLERRM
        );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION request_new_access_code(text) TO anon;
GRANT EXECUTE ON FUNCTION request_new_access_code(text) TO authenticated;