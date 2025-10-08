-- Updated User Function with Contact Information
-- This includes email and contact data from hr_employee_contacts table

-- Drop existing function
DROP FUNCTION IF EXISTS get_users_with_employee_details();

-- Create function with contact information included
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
    contact_number VARCHAR,
    whatsapp_number VARCHAR,
    branch_id BIGINT,
    position_id UUID,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        COALESCE(c.email, '')::VARCHAR as email,
        COALESCE(u.role_type::VARCHAR, 'Position-based') as role_type,
        COALESCE(u.status::VARCHAR, 'active') as status,
        u.employee_id,
        COALESCE(e.name, u.username)::VARCHAR as employee_name,
        COALESCE(e.employee_id, '')::VARCHAR as employee_code,
        COALESCE(e.status, 'active')::VARCHAR as employee_status,
        
        -- Get department through position
        COALESCE(d.department_name_en, 'No Department')::VARCHAR as department_name,
        COALESCE(p.position_title_en, 'No Position')::VARCHAR as position_title,
        COALESCE(b.name_en, 'No Branch')::VARCHAR as branch_name,
        
        -- Contact information
        COALESCE(c.contact_number, '')::VARCHAR as contact_number,
        COALESCE(c.whatsapp_number, '')::VARCHAR as whatsapp_number,
        
        -- IDs for filtering
        u.branch_id,
        u.position_id,
        
        u.created_at,
        u.updated_at
    FROM users u
    LEFT JOIN hr_employees e ON u.employee_id = e.id
    LEFT JOIN hr_employee_contacts c ON e.id = c.employee_id AND c.is_active = true
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

-- Test the updated function
SELECT 'Testing updated function with contact information:' as test;
SELECT id, username, email, employee_name, contact_number, branch_name 
FROM get_users_with_employee_details() 
LIMIT 5;