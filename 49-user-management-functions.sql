-- User Management Database Functions
-- This creates all the user-related RPC functions

-- Drop existing functions if they exist with different signatures
DROP FUNCTION IF EXISTS verify_password(VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS create_user(VARCHAR, VARCHAR, VARCHAR, VARCHAR, UUID, UUID);
DROP FUNCTION IF EXISTS generate_salt();
DROP FUNCTION IF EXISTS hash_password(TEXT, TEXT);
DROP FUNCTION IF EXISTS generate_unique_quick_access_code();
DROP FUNCTION IF EXISTS is_quick_access_code_available(VARCHAR);
DROP FUNCTION IF EXISTS get_quick_access_stats();
DROP FUNCTION IF EXISTS sync_employee_with_hr(UUID);

-- 1. Password verification function
CREATE OR REPLACE FUNCTION verify_password(
    input_username VARCHAR,
    input_password VARCHAR
)
RETURNS TABLE (
    user_id UUID,
    username VARCHAR,
    email VARCHAR,
    role_type VARCHAR,
    is_valid BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id as user_id,
        u.username,
        u.email,
        u.role_type,
        (u.password_hash = crypt(input_password, u.password_hash)) as is_valid
    FROM users u
    WHERE u.username = input_username
      AND u.deleted_at IS NULL
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create user function
CREATE OR REPLACE FUNCTION create_user(
    p_username VARCHAR,
    p_email VARCHAR,
    p_password_hash VARCHAR,
    p_role_type VARCHAR DEFAULT 'Employee',
    p_employee_id UUID DEFAULT NULL,
    p_branch_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    new_user_id UUID;
BEGIN
    INSERT INTO users (
        username,
        email,
        password_hash,
        role_type,
        employee_id,
        branch_id,
        status,
        created_at,
        updated_at
    ) VALUES (
        p_username,
        p_email,
        p_password_hash,
        p_role_type,
        p_employee_id,
        p_branch_id,
        'active',
        NOW(),
        NOW()
    ) RETURNING id INTO new_user_id;
    
    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Generate salt function
CREATE OR REPLACE FUNCTION generate_salt()
RETURNS TEXT AS $$
BEGIN
    RETURN gen_salt('bf', 8);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Hash password function
CREATE OR REPLACE FUNCTION hash_password(
    password TEXT,
    salt TEXT
)
RETURNS TEXT AS $$
BEGIN
    RETURN crypt(password, salt);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Generate unique quick access code
CREATE OR REPLACE FUNCTION generate_unique_quick_access_code()
RETURNS VARCHAR AS $$
DECLARE
    new_code VARCHAR(6);
    code_exists BOOLEAN;
BEGIN
    LOOP
        -- Generate a 6-digit random code
        new_code := LPAD(floor(random() * 1000000)::text, 6, '0');
        
        -- Check if code already exists
        SELECT EXISTS(
            SELECT 1 FROM users WHERE quick_access_code = new_code
        ) INTO code_exists;
        
        -- Exit loop if code is unique
        EXIT WHEN NOT code_exists;
    END LOOP;
    
    RETURN new_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Check if quick access code is available
CREATE OR REPLACE FUNCTION is_quick_access_code_available(
    code VARCHAR
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN NOT EXISTS(
        SELECT 1 FROM users 
        WHERE quick_access_code = code 
          AND deleted_at IS NULL
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Get quick access statistics
CREATE OR REPLACE FUNCTION get_quick_access_stats()
RETURNS TABLE (
    total_codes BIGINT,
    active_codes BIGINT,
    unused_codes BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_codes,
        COUNT(CASE WHEN status = 'active' THEN 1 END)::BIGINT as active_codes,
        COUNT(CASE WHEN quick_access_code IS NOT NULL AND last_login_at IS NULL THEN 1 END)::BIGINT as unused_codes
    FROM users
    WHERE deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Sync employee with HR function
CREATE OR REPLACE FUNCTION sync_employee_with_hr(
    p_employee_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Update user information based on employee record
    UPDATE users u
    SET 
        updated_at = NOW()
    FROM hr_employees e
    WHERE u.employee_id = e.id
      AND e.id = p_employee_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add missing columns to users table if they don't exist
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS quick_access_code VARCHAR(6) UNIQUE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS branch_id UUID;

-- Grant execute permissions on all functions
GRANT EXECUTE ON FUNCTION verify_password(VARCHAR, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION create_user(VARCHAR, VARCHAR, VARCHAR, VARCHAR, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_salt() TO authenticated;
GRANT EXECUTE ON FUNCTION hash_password(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_unique_quick_access_code() TO authenticated;
GRANT EXECUTE ON FUNCTION is_quick_access_code_available(VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION get_quick_access_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION sync_employee_with_hr(UUID) TO authenticated;

SELECT 'User management functions created successfully!' as status;