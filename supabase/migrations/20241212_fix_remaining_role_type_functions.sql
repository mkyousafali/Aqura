-- Migration: Fix remaining functions that reference users.role_type
-- Date: 2024-12-12
-- Description: Replace role_type column references with is_admin/is_master_admin boolean flags

-- ============================================================================
-- 1. Fix create_customer_registration function
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_customer_registration(p_name text, p_whatsapp_number text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
    
    -- Create notification for admin users
    BEGIN
        -- Get all admin user IDs (using boolean flags instead of role_type)
        SELECT array_agg(id::text) INTO v_admin_user_ids
        FROM public.users 
        WHERE (is_admin = true OR is_master_admin = true)
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
$function$;

-- ============================================================================
-- 2. Fix has_order_management_access function
-- ============================================================================
CREATE OR REPLACE FUNCTION public.has_order_management_access(user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users u
        LEFT JOIN user_roles ur ON u.position_id::text = ur.role_code
        WHERE u.id = user_id
        AND (
            -- Use boolean flags instead of role_type
            u.is_admin = true 
            OR u.is_master_admin = true
            OR ur.role_code IN (
                'CEO',
                'OPERATIONS_MANAGER',
                'BRANCH_MANAGER',
                'CUSTOMER_SERVICE_SUPERVISOR',
                'NIGHT_SUPERVISORS',
                'IT_SYSTEMS_MANAGER'
            )
        )
    );
END;
$function$;

-- ============================================================================
-- 3. Fix request_new_access_code function
-- ============================================================================
CREATE OR REPLACE FUNCTION public.request_new_access_code(p_whatsapp_number text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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

    -- Create notification for admin users
    BEGIN
        -- Get all admin user IDs (using boolean flags instead of role_type)
        DECLARE
            v_admin_user_ids text[];
        BEGIN
            SELECT array_agg(id::text) INTO v_admin_user_ids
            FROM public.users 
            WHERE (is_admin = true OR is_master_admin = true)
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
    
    RETURN result;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Failed to process account recovery request: ' || SQLERRM
        );
END;
$function$;

-- ============================================================================
-- 4. Fix verify_password function (the one that returns role_type)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.verify_password(input_username character varying, input_password character varying)
 RETURNS TABLE(user_id uuid, username character varying, email character varying, role_type character varying, is_valid boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        u.id as user_id,
        u.username,
        u.email,
        -- Return derived role_type for backward compatibility
        CASE 
            WHEN u.is_master_admin = true THEN 'Master Admin'::character varying
            WHEN u.is_admin = true THEN 'Admin'::character varying
            ELSE 'User'::character varying
        END as role_type,
        (u.password_hash = crypt(input_password, u.password_hash)) as is_valid
    FROM users u
    WHERE u.username = input_username
      AND u.deleted_at IS NULL
    LIMIT 1;
END;
$function$;

-- ============================================================================
-- Note: get_receiving_task_statistics functions DO NOT need fixing
-- They use receiving_tasks.role_type which is a task classification field,
-- not the deleted users.role_type column
-- ============================================================================

-- Migration complete
