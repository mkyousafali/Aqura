-- Fixed User Function with Correct Schema
-- This creates the function with columns that actually exist in the database

-- Drop existing function
DROP FUNCTION IF EXISTS get_users_with_employee_details();

-- Create function with correct column references
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
        ''::VARCHAR as email, -- Users table doesn't have email in our schema
        COALESCE(u.role_type::VARCHAR, 'Position-based') as role_type,
        COALESCE(u.status::VARCHAR, 'active') as status,
        u.employee_id,
        COALESCE(e.name, u.username)::VARCHAR as employee_name,
        COALESCE(e.employee_id, '')::VARCHAR as employee_code,
        COALESCE(e.status, 'active')::VARCHAR as employee_status,
        
        -- Get department through position (since hr_employees doesn't have department_id)
        COALESCE(d.department_name_en, 'No Department')::VARCHAR as department_name,
        COALESCE(p.position_title_en, 'No Position')::VARCHAR as position_title,
        COALESCE(b.name_en, 'No Branch')::VARCHAR as branch_name,
        
        u.created_at,
        u.updated_at
    FROM users u
    LEFT JOIN hr_employees e ON u.employee_id = e.id
    LEFT JOIN branches b ON u.branch_id = b.id
    LEFT JOIN hr_positions p ON u.position_id = p.id
    LEFT JOIN hr_departments d ON p.department_id = d.id
    WHERE u.status = 'active'
    ORDER BY u.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_users_with_employee_details() TO authenticated;
GRANT EXECUTE ON FUNCTION get_users_with_employee_details() TO anon;

-- Test the corrected function
SELECT 'Testing corrected function:' as test;
SELECT * FROM get_users_with_employee_details() LIMIT 5;

-- Also create a simple debugging function to check what users exist
CREATE OR REPLACE FUNCTION debug_users()
RETURNS TABLE (
    user_id UUID,
    username VARCHAR,
    status VARCHAR,
    employee_id UUID,
    branch_id BIGINT,
    position_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id as user_id,
        u.username,
        u.status::VARCHAR,
        u.employee_id,
        u.branch_id,
        u.position_id
    FROM users u
    ORDER BY u.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION debug_users() TO authenticated;
GRANT EXECUTE ON FUNCTION debug_users() TO anon;

-- Test debug function
SELECT 'Testing debug function:' as test;
SELECT * FROM debug_users() LIMIT 5;