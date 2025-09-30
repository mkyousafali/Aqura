-- Fix the database function to return proper text types
CREATE OR REPLACE FUNCTION get_users_with_employee_details()
RETURNS TABLE(
    user_id UUID,
    username TEXT,
    user_type TEXT,
    role_type TEXT,
    status TEXT,
    emp_id UUID,
    emp_name TEXT,
    emp_code TEXT,
    branch_id BIGINT,
    branch_name_en TEXT,
    branch_name_ar TEXT,
    position_id UUID,
    position_title_en TEXT,
    position_title_ar TEXT,
    contact_id UUID,
    email TEXT,
    contact_number TEXT,
    whatsapp_number TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id::UUID as user_id,
        u.username::TEXT as username,
        u.user_type::TEXT as user_type,
        u.role_type::TEXT as role_type,
        u.status::TEXT as status,
        e.id::UUID as emp_id,
        e.name::TEXT as emp_name,
        e.employee_id::TEXT as emp_code,
        e.branch_id::BIGINT as branch_id,
        b.name_en::TEXT as branch_name_en,
        b.name_ar::TEXT as branch_name_ar,
        p.id::UUID as position_id,
        p.position_title_en::TEXT as position_title_en,
        p.position_title_ar::TEXT as position_title_ar,
        c.id::UUID as contact_id,
        c.email::TEXT as email,
        c.contact_number::TEXT as contact_number,
        c.whatsapp_number::TEXT as whatsapp_number
    FROM users u
    LEFT JOIN hr_employees e ON u.employee_id = e.id
    LEFT JOIN branches b ON e.branch_id = b.id
    LEFT JOIN hr_position_assignments pa ON e.id = pa.employee_id
    LEFT JOIN hr_positions p ON pa.position_id = p.id
    LEFT JOIN hr_employee_contacts c ON e.id = c.employee_id
    WHERE u.status = 'active'
    ORDER BY u.username;
END;
$$ LANGUAGE plpgsql;