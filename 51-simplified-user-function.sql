-- Simplified User Function for Testing
-- This creates a simpler version that should definitely return users

-- Drop and recreate with a simpler approach
DROP FUNCTION IF EXISTS get_users_with_employee_details();

-- Simple version that just returns basic user info
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
        COALESCE(u.email, '')::VARCHAR as email,
        COALESCE(u.role_type, 'Employee')::VARCHAR as role_type,
        COALESCE(u.status, 'active')::VARCHAR as status,
        u.employee_id,
        COALESCE(e.first_name || ' ' || COALESCE(e.last_name, ''), e.first_name, u.username)::VARCHAR as employee_name,
        COALESCE(e.employee_code, '')::VARCHAR as employee_code,
        COALESCE(e.status::VARCHAR, 'active') as employee_status,
        COALESCE(d.name, 'No Department')::VARCHAR as department_name,
        COALESCE(p.title, 'No Position')::VARCHAR as position_title,
        COALESCE(b.name, 'No Branch')::VARCHAR as branch_name,
        u.created_at,
        u.updated_at
    FROM users u
    LEFT JOIN hr_employees e ON u.employee_id = e.id
    LEFT JOIN hr_departments d ON e.department_id = d.id
    LEFT JOIN hr_positions p ON e.position_id = p.id
    LEFT JOIN branches b ON e.branch_id = b.id
    WHERE u.deleted_at IS NULL
      AND COALESCE(u.status, 'active') = 'active'
    ORDER BY u.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_users_with_employee_details() TO authenticated;
GRANT EXECUTE ON FUNCTION get_users_with_employee_details() TO anon;

-- Even simpler fallback function
CREATE OR REPLACE FUNCTION get_simple_users()
RETURNS TABLE (
    id UUID,
    username VARCHAR,
    email VARCHAR,
    role_type VARCHAR,
    status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        COALESCE(u.email, '')::VARCHAR as email,
        COALESCE(u.role_type, 'Employee')::VARCHAR as role_type,
        'active'::VARCHAR as status
    FROM users u
    WHERE u.deleted_at IS NULL
    ORDER BY u.username;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions for simple function
GRANT EXECUTE ON FUNCTION get_simple_users() TO authenticated;
GRANT EXECUTE ON FUNCTION get_simple_users() TO anon;

-- Test both functions
SELECT 'Testing simplified function:' as test;
SELECT * FROM get_users_with_employee_details() LIMIT 3;

SELECT 'Testing simple function:' as test;
SELECT * FROM get_simple_users() LIMIT 3;