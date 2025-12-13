-- Fix approve_customer_account to use p_approved_by parameter instead of auth.uid()
-- Since we're using custom authentication (not Supabase Auth), auth.uid() returns NULL
-- We need to trust the p_approved_by parameter and verify that user has admin privileges

CREATE OR REPLACE FUNCTION public.approve_customer_account(
    p_customer_id uuid, 
    p_status text, 
    p_notes text DEFAULT ''::text, 
    p_approved_by uuid DEFAULT NULL::uuid
)
RETURNS TABLE(success boolean, message text, customer_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_current_status TEXT;
    v_approved_by UUID;
    v_is_admin BOOLEAN;
    v_is_master_admin BOOLEAN;
BEGIN
    -- p_approved_by is required since we use custom auth (not Supabase Auth)
    IF p_approved_by IS NULL THEN
        RAISE EXCEPTION 'User ID (p_approved_by) is required.';
    END IF;

    -- Check if the user making the request has admin privileges
    SELECT is_admin, is_master_admin 
    INTO v_is_admin, v_is_master_admin
    FROM users 
    WHERE id = p_approved_by;

    -- Verify user exists and has admin privileges
    IF v_is_admin IS NULL THEN
        RAISE EXCEPTION 'User not found.';
    END IF;

    IF NOT (v_is_admin = true OR v_is_master_admin = true) THEN
        RAISE EXCEPTION 'Access denied. Admin privileges required.';
    END IF;

    -- Validate status parameter
    IF p_status NOT IN ('approved', 'rejected') THEN
        RETURN QUERY SELECT FALSE, 'Invalid status. Must be approved or rejected.', NULL::UUID;
        RETURN;
    END IF;

    -- Use the provided user ID
    v_approved_by := p_approved_by;

    -- Get current customer status
    SELECT registration_status INTO v_current_status
    FROM customers
    WHERE id = p_customer_id;

    -- Check if customer exists
    IF v_current_status IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Customer not found.', NULL::UUID;
        RETURN;
    END IF;

    -- Check if customer is already processed
    IF v_current_status != 'pending' THEN
        RETURN QUERY SELECT FALSE, 'Customer has already been processed.', NULL::UUID;
        RETURN;
    END IF;

    -- Update customer status
    UPDATE customers
    SET 
        registration_status = p_status,
        approved_at = CURRENT_TIMESTAMP,
        approved_by = v_approved_by,
        registration_notes = p_notes,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_customer_id;

    -- Return success
    RETURN QUERY SELECT TRUE, 'Customer ' || p_status || ' successfully.', p_customer_id;
END;
$function$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.approve_customer_account TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_customer_account TO anon;
