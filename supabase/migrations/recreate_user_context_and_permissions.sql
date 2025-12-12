-- Migration: Recreate user context and permissions view without role_type
-- Date: 2025-12-12
-- Purpose: Replace role_type-dependent objects with new boolean flag system

-- ============================================================
-- PART 1: Create set_user_context RPC function
-- ============================================================
-- Drop old version of function (with role_type parameter)
DROP FUNCTION IF EXISTS set_user_context(UUID, VARCHAR);
DROP FUNCTION IF EXISTS set_user_context(UUID, TEXT);

-- This function sets the current user context for RLS policies
CREATE OR REPLACE FUNCTION set_user_context(
  user_id UUID,
  is_master_admin BOOLEAN DEFAULT false,
  is_admin BOOLEAN DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Set configuration variables that RLS policies can access
  PERFORM set_config('app.current_user_id', user_id::text, false);
  PERFORM set_config('app.is_master_admin', is_master_admin::text, false);
  PERFORM set_config('app.is_admin', is_admin::text, false);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION set_user_context TO authenticated;
GRANT EXECUTE ON FUNCTION set_user_context TO anon;

-- ============================================================
-- PART 2: Create user_permissions_view (if button permissions exist)
-- ============================================================
-- This view shows button-based permissions for users
-- Note: This replaces the old role-based permission system

CREATE OR REPLACE VIEW user_permissions_view AS
SELECT 
  bp.user_id,
  u.username,
  sb.button_code as function_code,
  sb.button_name_en as function_name,
  -- For button permissions, we grant all actions when enabled
  bp.is_enabled as can_view,
  bp.is_enabled as can_add,
  bp.is_enabled as can_edit,
  bp.is_enabled as can_delete,
  bp.is_enabled as can_export
FROM button_permissions bp
JOIN users u ON bp.user_id = u.id
JOIN sidebar_buttons sb ON bp.button_id = sb.id
WHERE bp.is_enabled = true;

-- Grant select permission
GRANT SELECT ON user_permissions_view TO authenticated;
GRANT SELECT ON user_permissions_view TO anon;

-- ============================================================
-- PART 3: Create helper function to check if user is admin
-- ============================================================
CREATE OR REPLACE FUNCTION is_user_admin(check_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_is_master_admin BOOLEAN;
  user_is_admin BOOLEAN;
BEGIN
  SELECT is_master_admin, is_admin
  INTO user_is_master_admin, user_is_admin
  FROM users
  WHERE id = check_user_id;
  
  RETURN COALESCE(user_is_master_admin, false) OR COALESCE(user_is_admin, false);
END;
$$;

GRANT EXECUTE ON FUNCTION is_user_admin TO authenticated;
GRANT EXECUTE ON FUNCTION is_user_admin TO anon;

-- ============================================================
-- PART 4: Create helper function to check if user is master admin
-- ============================================================
CREATE OR REPLACE FUNCTION is_user_master_admin(check_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_is_master_admin BOOLEAN;
BEGIN
  SELECT is_master_admin
  INTO user_is_master_admin
  FROM users
  WHERE id = check_user_id;
  
  RETURN COALESCE(user_is_master_admin, false);
END;
$$;

GRANT EXECUTE ON FUNCTION is_user_master_admin TO authenticated;
GRANT EXECUTE ON FUNCTION is_user_master_admin TO anon;

-- ============================================================
-- PART 5: Create helper to get current user from context
-- ============================================================
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN current_setting('app.current_user_id', true)::UUID;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION get_current_user_id TO authenticated;
GRANT EXECUTE ON FUNCTION get_current_user_id TO anon;

-- ============================================================
-- PART 6: Create helper to check current user admin status
-- ============================================================
CREATE OR REPLACE FUNCTION current_user_is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN current_setting('app.is_master_admin', true)::BOOLEAN 
         OR current_setting('app.is_admin', true)::BOOLEAN;
EXCEPTION
  WHEN OTHERS THEN
    RETURN false;
END;
$$;

GRANT EXECUTE ON FUNCTION current_user_is_admin TO authenticated;
GRANT EXECUTE ON FUNCTION current_user_is_admin TO anon;

-- ============================================================
-- Notes:
-- ============================================================
-- These functions replace the old role_type-based system with the new
-- is_master_admin and is_admin boolean flags.
--
-- The user_permissions_view now uses button_permissions instead of
-- role_permissions, aligning with the new button-based access control.
--
-- RLS policies can now use these helper functions instead of checking
-- role_type enum values.
