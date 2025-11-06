-- Create function to get customers list for admin management
-- File: supabase/migrations/database-functions/misc/get_customers_list.sql

-- Drop existing function first to handle return type changes
DROP FUNCTION IF EXISTS get_customers_list();

CREATE OR REPLACE FUNCTION get_customers_list()
RETURNS TABLE (
    id UUID,
    name TEXT,
    access_code VARCHAR(6),
    whatsapp_number VARCHAR(20),
    registration_status TEXT,
    registration_notes TEXT,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    access_code_generated_at TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Return all customers with their actual information matching schema
    RETURN QUERY
    SELECT 
        c.id,
        c.name,
        c.access_code,
        c.whatsapp_number,
        c.registration_status,
        c.registration_notes,
        c.approved_by,
        c.approved_at,
        c.access_code_generated_at,
        c.last_login_at,
        c.created_at,
        c.updated_at
    FROM customers c
    ORDER BY 
        CASE 
            WHEN c.registration_status = 'pending' THEN 1
            WHEN c.registration_status = 'approved' THEN 2
            WHEN c.registration_status = 'rejected' THEN 3
            WHEN c.registration_status = 'suspended' THEN 4
            ELSE 5
        END,
        c.created_at DESC;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_customers_list() TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION get_customers_list() IS 'Returns list of all customers for admin management. Requires admin privileges.';