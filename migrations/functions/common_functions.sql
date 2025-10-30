-- Common Database Functions
-- Generated on: 2025-10-30T21:55:45.335Z

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate notification reference
CREATE OR REPLACE FUNCTION public.generate_notification_reference()
RETURNS TEXT AS $$
BEGIN
    RETURN 'NOT-' || to_char(now(), 'YYYYMMDD') || '-' || 
           LPAD(nextval('notification_sequence')::text, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- Function to generate warning reference
CREATE OR REPLACE FUNCTION public.generate_warning_reference()
RETURNS TEXT AS $$
BEGIN
    RETURN 'WRN-' || to_char(now(), 'YYYYMMDD') || '-' || 
           LPAD(nextval('warning_sequence')::text, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- Function to generate task reference
CREATE OR REPLACE FUNCTION public.generate_task_reference()
RETURNS TEXT AS $$
BEGIN
    RETURN 'TSK-' || to_char(now(), 'YYYYMMDD') || '-' || 
           LPAD(nextval('task_sequence')::text, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- Create sequences for reference generators
CREATE SEQUENCE IF NOT EXISTS notification_sequence START 1;
CREATE SEQUENCE IF NOT EXISTS warning_sequence START 1;
CREATE SEQUENCE IF NOT EXISTS task_sequence START 1;

-- Function to check user permissions
CREATE OR REPLACE FUNCTION public.check_user_permission(
    user_uuid UUID,
    permission_name TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM user_roles ur
        JOIN role_permissions rp ON ur.role_id = rp.role_id
        WHERE ur.user_id = user_uuid 
        AND rp.permission = permission_name
        AND ur.is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user branch
CREATE OR REPLACE FUNCTION public.get_user_branch(user_uuid UUID)
RETURNS UUID AS $$
DECLARE
    branch_uuid UUID;
BEGIN
    SELECT he.branch_id INTO branch_uuid
    FROM hr_employees he
    JOIN users u ON u.employee_id = he.id
    WHERE u.id = user_uuid;
    
    RETURN branch_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
