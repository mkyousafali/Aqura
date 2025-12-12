-- Migration: Create user management RPC function
-- Date: 2025-12-12
-- Purpose: Create RPC function for user creation with new boolean admin flags

-- Drop all versions of the functions using CASCADE
DROP FUNCTION IF EXISTS create_user CASCADE;
DROP FUNCTION IF EXISTS update_user CASCADE;

-- ============================================================
-- PART 1: Create user function
-- ============================================================

CREATE FUNCTION create_user(
  p_username VARCHAR,
  p_password VARCHAR,
  p_is_master_admin BOOLEAN DEFAULT false,
  p_is_admin BOOLEAN DEFAULT false,
  p_user_type VARCHAR DEFAULT 'branch_specific',
  p_branch_id INTEGER DEFAULT NULL,
  p_employee_id VARCHAR DEFAULT NULL,
  p_position_id VARCHAR DEFAULT NULL,
  p_quick_access_code VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_quick_access_code VARCHAR(6);
  v_password_hash TEXT;
BEGIN
  -- Generate quick access code if not provided
  IF p_quick_access_code IS NULL THEN
    -- Generate random 6-digit code
    v_quick_access_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
    
    -- Ensure uniqueness
    WHILE EXISTS (SELECT 1 FROM users WHERE quick_access_code = v_quick_access_code) LOOP
      v_quick_access_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
    END LOOP;
  ELSE
    v_quick_access_code := p_quick_access_code;
    
    -- Check if quick access code already exists
    IF EXISTS (SELECT 1 FROM users WHERE quick_access_code = v_quick_access_code) THEN
      RETURN json_build_object(
        'success', false,
        'message', 'Quick access code already exists'
      );
    END IF;
  END IF;

  -- Check if username already exists
  IF EXISTS (SELECT 1 FROM users WHERE username = p_username) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Username already exists'
    );
  END IF;

  -- Hash the password using crypt
  v_password_hash := crypt(p_password, gen_salt('bf'));

  -- Insert new user
  INSERT INTO users (
    username,
    password_hash,
    quick_access_code,
    is_master_admin,
    is_admin,
    user_type,
    branch_id,
    employee_id,
    position_id,
    status,
    is_first_login,
    failed_login_attempts,
    created_at,
    updated_at
  ) VALUES (
    p_username,
    v_password_hash,
    v_quick_access_code,
    p_is_master_admin,
    p_is_admin,
    p_user_type::user_type,
    p_branch_id,
    p_employee_id,
    p_position_id,
    'active',
    true,
    0,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_user_id;

  -- Return success with user details
  RETURN json_build_object(
    'success', true,
    'user_id', v_user_id,
    'quick_access_code', v_quick_access_code,
    'message', 'User created successfully'
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'message', SQLERRM
    );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION create_user TO authenticated;
GRANT EXECUTE ON FUNCTION create_user TO anon;

-- ============================================================
-- PART 2: Update user function
-- ============================================================

CREATE FUNCTION update_user(
  p_user_id UUID,
  p_username VARCHAR DEFAULT NULL,
  p_is_master_admin BOOLEAN DEFAULT NULL,
  p_is_admin BOOLEAN DEFAULT NULL,
  p_user_type VARCHAR DEFAULT NULL,
  p_branch_id INTEGER DEFAULT NULL,
  p_employee_id VARCHAR DEFAULT NULL,
  p_position_id VARCHAR DEFAULT NULL,
  p_status VARCHAR DEFAULT NULL,
  p_avatar TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if user exists
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'User not found'
    );
  END IF;

  -- Check if username is being changed and if it's already taken
  IF p_username IS NOT NULL AND p_username != (SELECT username FROM users WHERE id = p_user_id) THEN
    IF EXISTS (SELECT 1 FROM users WHERE username = p_username AND id != p_user_id) THEN
      RETURN json_build_object(
        'success', false,
        'message', 'Username already exists'
      );
    END IF;
  END IF;

  -- Update user with provided fields
  UPDATE users
  SET
    username = COALESCE(p_username, username),
    is_master_admin = COALESCE(p_is_master_admin, is_master_admin),
    is_admin = COALESCE(p_is_admin, is_admin),
    user_type = COALESCE(p_user_type::user_type, user_type),
    branch_id = CASE WHEN p_branch_id IS NOT NULL THEN p_branch_id ELSE branch_id END,
    employee_id = COALESCE(p_employee_id, employee_id),
    position_id = COALESCE(p_position_id, position_id),
    status = COALESCE(p_status::user_status, status),
    avatar = COALESCE(p_avatar, avatar),
    updated_at = NOW()
  WHERE id = p_user_id;

  RETURN json_build_object(
    'success', true,
    'message', 'User updated successfully'
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'message', SQLERRM
    );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_user TO authenticated;
GRANT EXECUTE ON FUNCTION update_user TO anon;
