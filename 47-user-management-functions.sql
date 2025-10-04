-- Missing Database Functions for User Management
-- This creates the get_users_with_employee_details function that the frontend needs

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_users_with_employee_details();

-- Function to get users with their employee details
CREATE OR REPLACE FUNCTION get_users_with_employee_details()
RETURNS TABLE (
    id UUID,
    username VARCHAR,
    email VARCHAR,
    role_type VARCHAR,
    status VARCHAR,
    employee_id UUID,
    employee_name VARCHAR,
    employee_code VARCHAR,
    employee_status VARCHAR,
    department_name VARCHAR,
    position_title VARCHAR,
    branch_name VARCHAR,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        u.email,
        u.role_type,
        COALESCE(e.status, 'active')::VARCHAR as status,  -- Use employee status, fallback to 'active'
        u.employee_id,
        COALESCE(e.first_name || ' ' || e.last_name, e.first_name, 'Unknown')::VARCHAR as employee_name,
        e.employee_code,
        e.status::VARCHAR as employee_status,
        d.name::VARCHAR as department_name,
        p.title::VARCHAR as position_title,
        b.name::VARCHAR as branch_name,
        u.created_at,
        u.updated_at
    FROM users u
    LEFT JOIN hr_employees e ON u.employee_id = e.id
    LEFT JOIN hr_departments d ON e.department_id = d.id
    LEFT JOIN hr_positions p ON e.position_id = p.id
    LEFT JOIN branches b ON e.branch_id = b.id
    WHERE u.deleted_at IS NULL
    ORDER BY u.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions for the function
GRANT EXECUTE ON FUNCTION get_users_with_employee_details() TO authenticated;
GRANT EXECUTE ON FUNCTION get_users_with_employee_details() TO anon;

-- Alternative simpler function if the complex one doesn't work
CREATE OR REPLACE FUNCTION get_all_users()
RETURNS TABLE (
    id UUID,
    username VARCHAR,
    email VARCHAR,
    role_type VARCHAR,
    status VARCHAR,
    employee_id UUID,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        u.email,
        u.role_type,
        'active'::VARCHAR as status,  -- Default status since column doesn't exist
        u.employee_id,
        u.created_at,
        u.updated_at
    FROM users u
    WHERE u.deleted_at IS NULL
    ORDER BY u.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions for the simpler function
GRANT EXECUTE ON FUNCTION get_all_users() TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_users() TO anon;

-- Add status column to users table if it doesn't exist
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'active';

-- Test the function
SELECT 'Database functions created successfully!' as status;