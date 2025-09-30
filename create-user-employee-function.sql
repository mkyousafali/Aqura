-- Create function to get users with complete employee details in flat structure
CREATE OR REPLACE FUNCTION get_users_with_employee_details()
RETURNS TABLE (
    id UUID,
    username TEXT,
    user_type TEXT,
    role_type TEXT,
    status TEXT,
    branch_id UUID,
    employee_id UUID,
    emp_name TEXT,
    email TEXT,
    contact_number TEXT,
    whatsapp_number TEXT,
    position_title_en TEXT,
    branch_name_en TEXT,
    hire_date DATE,
    avatar TEXT,
    avatar_medium_url TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        u.user_type,
        u.role_type,
        u.status,
        u.branch_id,
        u.employee_id,
        e.name as emp_name,
        
        -- Contact info from hr_employee_contacts table
        ec.email,
        ec.contact_number,
        ec.whatsapp_number,
        
        -- Position info
        p.position_title_en,
        b.name_en as branch_name_en,
        e.hire_date,
        u.avatar,
        u.avatar_medium_url
        
    FROM users u
    LEFT JOIN hr_employees e ON u.employee_id = e.id
    LEFT JOIN hr_employee_contacts ec ON e.id = ec.employee_id AND ec.is_active = true
    LEFT JOIN hr_position_assignments pa ON e.id = pa.employee_id AND pa.is_current = true
    LEFT JOIN hr_positions p ON pa.position_id = p.id
    LEFT JOIN branches b ON pa.branch_id = b.id
    WHERE u.status = 'active'
    ORDER BY u.username;
END;
$$ LANGUAGE plpgsql;