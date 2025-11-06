-- ================================================================
-- APPLY CUSTOMER DATABASE FUNCTIONS
-- Run this script in Supabase SQL Editor to apply the customer functions
-- ================================================================

-- Drop existing functions first to avoid type conflicts
DROP FUNCTION IF EXISTS get_customers_list();
DROP FUNCTION IF EXISTS approve_customer_account(UUID, TEXT, TEXT, UUID);

-- 1. Create get_customers_list function
CREATE OR REPLACE FUNCTION get_customers_list()
RETURNS TABLE (
    id UUID,
    username CHARACTER VARYING,
    access_code CHARACTER VARYING,
    customer_name CHARACTER VARYING,
    company_name CHARACTER VARYING,
    whatsapp_number CHARACTER VARYING,
    status CHARACTER VARYING,
    created_at TIMESTAMPTZ,
    approved_at TIMESTAMPTZ,
    approved_by UUID,
    notes CHARACTER VARYING
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Return all customers with basic information
    -- Note: Since the current database structure doesn't have dedicated customer name/company fields,
    -- we'll use placeholders that can be enhanced later
    RETURN QUERY
    SELECT 
        c.id,
        COALESCE(u.username, 'Unknown User')::CHARACTER VARYING as username,
        COALESCE(c.access_code, 'Not Generated')::CHARACTER VARYING as access_code,
        COALESCE(u.username, 'Customer')::CHARACTER VARYING as customer_name,
        'Customer Account'::CHARACTER VARYING as company_name,
        COALESCE(c.whatsapp_number, 'Not Provided')::CHARACTER VARYING as whatsapp_number,
        c.registration_status::CHARACTER VARYING as status,
        c.created_at,
        c.approved_at,
        c.approved_by,
        COALESCE(c.registration_notes, 'No notes')::CHARACTER VARYING as notes
    FROM customers c
    LEFT JOIN users u ON c.user_id = u.id
    ORDER BY 
        CASE 
            WHEN c.registration_status = 'pending' THEN 1
            WHEN c.registration_status = 'approved' THEN 2
            WHEN c.registration_status = 'rejected' THEN 3
            ELSE 4
        END,
        c.created_at DESC;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_customers_list() TO authenticated;

-- Add comment
COMMENT ON FUNCTION get_customers_list() IS 'Returns list of all customers for admin management. Requires admin privileges.';

-- 2. Create approve_customer_account function
CREATE OR REPLACE FUNCTION approve_customer_account(
    p_customer_id UUID,
    p_status TEXT,
    p_notes TEXT DEFAULT '',
    p_approved_by UUID DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    customer_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_status TEXT;
    v_approved_by UUID;
BEGIN
    -- Validate status parameter
    IF p_status NOT IN ('approved', 'rejected') THEN
        RETURN QUERY SELECT FALSE, 'Invalid status. Must be approved or rejected.', NULL::UUID;
        RETURN;
    END IF;

    -- Set approved_by to current user if not provided
    v_approved_by := COALESCE(p_approved_by, auth.uid());

    -- Get current customer status (using registration_status not status)
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

    -- Update customer status (using registration_status not status)
    UPDATE customers
    SET 
        registration_status = p_status,
        approved_at = CURRENT_TIMESTAMP,
        approved_by = v_approved_by,
        registration_notes = CASE WHEN p_status = 'approved' THEN p_notes ELSE registration_notes END,
        rejection_notes = CASE WHEN p_status = 'rejected' THEN p_notes ELSE rejection_notes END,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_customer_id;

    -- If approved, update user account for customer login
    IF p_status = 'approved' THEN
        -- Update the existing user record to enable customer access
        UPDATE users
        SET 
            role_type = 'Customer',
            user_type = 'customer',
            updated_at = CURRENT_TIMESTAMP
        FROM customers c
        WHERE users.id = c.user_id 
        AND c.id = p_customer_id;

        -- Enable customer interface for this user
        UPDATE interface_permissions
        SET 
            customer_enabled = true,
            updated_by = v_approved_by,
            notes = 'Customer access approved by admin',
            updated_at = CURRENT_TIMESTAMP
        FROM customers c
        WHERE interface_permissions.user_id = c.user_id 
        AND c.id = p_customer_id;
    END IF;

    -- Return success
    RETURN QUERY SELECT TRUE, 'Customer ' || p_status || ' successfully.', p_customer_id;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION approve_customer_account(UUID, TEXT, TEXT, UUID) TO authenticated;

-- Add comment
COMMENT ON FUNCTION approve_customer_account(UUID, TEXT, TEXT, UUID) IS 'Approves or rejects a customer account. Requires admin privileges. Creates user account for approved customers.';

-- ================================================================
-- COMPLETED: Customer Functions Applied
-- ================================================================