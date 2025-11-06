-- ================================================================
-- Function: get_user_interface_permissions
-- Category: user
-- Return Type: json
-- Arguments: p_user_id uuid
-- Description: Gets user's interface access permissions
-- ================================================================

CREATE OR REPLACE FUNCTION get_user_interface_permissions(
    p_user_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_permissions record;
    v_user_type text;
    result json;
BEGIN
    -- Get user type
    SELECT user_type INTO v_user_type
    FROM public.users
    WHERE id = p_user_id;
    
    IF v_user_type IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Get interface permissions
    SELECT 
        desktop_enabled,
        mobile_enabled,
        customer_enabled
    INTO v_permissions
    FROM public.interface_permissions
    WHERE user_id = p_user_id;
    
    -- If no permissions record exists, create default
    IF v_permissions IS NULL THEN
        INSERT INTO public.interface_permissions (
            user_id,
            desktop_enabled,
            mobile_enabled,
            customer_enabled,
            updated_by
        ) VALUES (
            p_user_id,
            CASE WHEN v_user_type = 'customer' THEN false ELSE true END,
            CASE WHEN v_user_type = 'customer' THEN false ELSE true END,
            CASE WHEN v_user_type = 'customer' THEN true ELSE false END,
            p_user_id
        ) RETURNING desktop_enabled, mobile_enabled, customer_enabled
        INTO v_permissions;
    END IF;
    
    -- Return permissions
    result := json_build_object(
        'success', true,
        'user_id', p_user_id,
        'user_type', v_user_type,
        'permissions', json_build_object(
            'desktop_enabled', v_permissions.desktop_enabled,
            'mobile_enabled', v_permissions.mobile_enabled,
            'customer_enabled', v_permissions.customer_enabled
        )
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