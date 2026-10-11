BEGIN;

-- Keep the login/user record aligned when an employee is edited from
-- HR > Employee Master.
CREATE OR REPLACE FUNCTION public.update_employee_master_basic(
  p_id text,
  p_name_en text DEFAULT NULL,
  p_name_ar text DEFAULT NULL,
  p_current_branch_id integer DEFAULT NULL,
  p_current_position_id uuid DEFAULT NULL,
  p_whatsapp_number text DEFAULT NULL,
  p_email text DEFAULT NULL
)
RETURNS TABLE(
  id text,
  name_en varchar,
  name_ar varchar,
  current_branch_id integer,
  current_position_id uuid,
  whatsapp_number text,
  email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  IF COALESCE(trim(p_id), '') = '' THEN
    RAISE EXCEPTION 'Employee ID is required';
  END IF;

  IF p_current_branch_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.branches AS b WHERE b.id = p_current_branch_id) THEN
    RAISE EXCEPTION 'Branch not found';
  END IF;

  IF p_current_position_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.hr_positions AS pos WHERE pos.id = p_current_position_id) THEN
    RAISE EXCEPTION 'Position not found';
  END IF;

  SELECT employee.user_id
  INTO v_user_id
  FROM public.hr_employee_master AS employee
  WHERE employee.id = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Employee not found';
  END IF;

  UPDATE public.hr_employee_master AS employee
  SET
    name_en = COALESCE(NULLIF(trim(p_name_en), ''), employee.name_en),
    name_ar = COALESCE(NULLIF(trim(p_name_ar), ''), employee.name_ar),
    current_branch_id = COALESCE(p_current_branch_id, employee.current_branch_id),
    current_position_id = COALESCE(p_current_position_id, employee.current_position_id),
    whatsapp_number = CASE
      WHEN p_whatsapp_number IS NOT NULL THEN NULLIF(trim(p_whatsapp_number), '')
      ELSE employee.whatsapp_number
    END,
    email = CASE
      WHEN p_email IS NOT NULL THEN NULLIF(trim(p_email), '')
      ELSE employee.email
    END,
    updated_at = now()
  WHERE employee.id = p_id;

  IF v_user_id IS NOT NULL
     AND (p_current_branch_id IS NOT NULL OR p_current_position_id IS NOT NULL) THEN
    UPDATE public.users AS linked_user
    SET
      branch_id = COALESCE(p_current_branch_id::bigint, linked_user.branch_id),
      position_id = COALESCE(p_current_position_id, linked_user.position_id),
      updated_at = now()
    WHERE linked_user.id = v_user_id;
  END IF;

  RETURN QUERY
  SELECT
    employee.id,
    employee.name_en,
    employee.name_ar,
    employee.current_branch_id,
    employee.current_position_id,
    employee.whatsapp_number,
    employee.email
  FROM public.hr_employee_master AS employee
  WHERE employee.id = p_id;
END;
$$;

-- Keep the HR employee record aligned when a user is edited from
-- Settings > User Management.
CREATE OR REPLACE FUNCTION public.update_user(
  p_user_id uuid,
  p_username character varying DEFAULT NULL,
  p_is_master_admin boolean DEFAULT NULL,
  p_is_admin boolean DEFAULT NULL,
  p_user_type character varying DEFAULT NULL,
  p_branch_id bigint DEFAULT NULL,
  p_employee_id uuid DEFAULT NULL,
  p_position_id uuid DEFAULT NULL,
  p_status character varying DEFAULT NULL,
  p_avatar text DEFAULT NULL,
  p_requesting_user_id uuid DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_requester_is_master boolean := false;
  v_requester_can_manage boolean := false;
  v_target_is_master boolean;
  v_target_is_admin boolean;
BEGIN
  SELECT u.is_master_admin, u.is_admin
    INTO v_target_is_master, v_target_is_admin
    FROM public.users u
   WHERE u.id = p_user_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'User not found');
  END IF;

  SELECT COALESCE(u.is_master_admin, false)
    INTO v_requester_is_master
    FROM public.users u
   WHERE u.id = p_requesting_user_id AND u.status = 'active';

  SELECT EXISTS (
    SELECT 1 FROM public.button_permissions bp
     WHERE bp.user_id = p_requesting_user_id
       AND bp.button_code = 'USER_MANAGEMENT'
       AND bp.is_enabled = true
  ) INTO v_requester_can_manage;

  IF NOT COALESCE(v_requester_is_master, false)
     AND NOT COALESCE(v_requester_can_manage, false) THEN
    RETURN json_build_object('success', false, 'message', 'Access denied: User Management permission required');
  END IF;

  IF ((p_is_master_admin IS NOT NULL AND p_is_master_admin IS DISTINCT FROM v_target_is_master)
      OR (p_is_admin IS NOT NULL AND p_is_admin IS DISTINCT FROM v_target_is_admin))
     AND NOT COALESCE(v_requester_is_master, false) THEN
    RETURN json_build_object('success', false, 'message', 'Access denied: only a Master Admin can change Admin privileges');
  END IF;

  IF p_username IS NOT NULL AND p_username <> (SELECT username FROM public.users WHERE id = p_user_id)
     AND EXISTS (SELECT 1 FROM public.users WHERE username = p_username AND id <> p_user_id) THEN
    RETURN json_build_object('success', false, 'message', 'Username already exists');
  END IF;

  IF p_position_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.hr_positions AS pos WHERE pos.id = p_position_id) THEN
    RETURN json_build_object('success', false, 'message', 'Position not found');
  END IF;

  UPDATE public.users SET
    username = COALESCE(p_username, username),
    is_master_admin = COALESCE(p_is_master_admin, is_master_admin),
    is_admin = COALESCE(p_is_admin, is_admin),
    user_type = CASE WHEN p_user_type IS NULL THEN user_type ELSE p_user_type::public.user_type_enum END,
    branch_id = COALESCE(p_branch_id, branch_id),
    employee_id = COALESCE(p_employee_id, employee_id),
    position_id = COALESCE(p_position_id, position_id),
    status = COALESCE(p_status, status),
    avatar = COALESCE(p_avatar, avatar),
    updated_at = now()
  WHERE id = p_user_id;

  IF p_position_id IS NOT NULL THEN
    UPDATE public.hr_employee_master AS employee
    SET
      current_position_id = p_position_id,
      updated_at = now()
    WHERE employee.user_id = p_user_id;
  END IF;

  RETURN json_build_object('success', true, 'message', 'User updated successfully');
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

COMMIT;
