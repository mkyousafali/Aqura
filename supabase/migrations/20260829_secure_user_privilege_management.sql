-- Restrict employee-account creation/editing and reserve Admin/Master Admin
-- assignment for an existing Master Admin.

DROP FUNCTION IF EXISTS public.create_user(character varying, character varying, boolean, boolean, character varying, bigint, uuid, uuid, character varying);

CREATE FUNCTION public.create_user(
  p_username character varying,
  p_password character varying,
  p_is_master_admin boolean DEFAULT false,
  p_is_admin boolean DEFAULT false,
  p_user_type character varying DEFAULT 'branch_specific'::character varying,
  p_branch_id bigint DEFAULT NULL::bigint,
  p_employee_id uuid DEFAULT NULL::uuid,
  p_position_id uuid DEFAULT NULL::uuid,
  p_quick_access_code character varying DEFAULT NULL::character varying,
  p_requesting_user_id uuid DEFAULT NULL::uuid
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid;
  v_quick_access_code varchar(6);
  v_quick_access_hash text;
  v_password_hash text;
  v_salt text;
  v_quick_access_salt text;
  v_requester_is_master boolean := false;
  v_requester_can_create boolean := false;
BEGIN
  SELECT COALESCE(u.is_master_admin, false)
    INTO v_requester_is_master
    FROM public.users u
   WHERE u.id = p_requesting_user_id AND u.status = 'active';

  SELECT EXISTS (
    SELECT 1 FROM public.button_permissions bp
     WHERE bp.user_id = p_requesting_user_id
       AND bp.button_code = 'CREATE_USER'
       AND bp.is_enabled = true
  ) INTO v_requester_can_create;

  IF NOT COALESCE(v_requester_is_master, false)
     AND NOT COALESCE(v_requester_can_create, false) THEN
    RETURN json_build_object('success', false, 'message', 'Access denied: Create User permission required');
  END IF;

  IF (COALESCE(p_is_admin, false) OR COALESCE(p_is_master_admin, false))
     AND NOT COALESCE(v_requester_is_master, false) THEN
    RETURN json_build_object('success', false, 'message', 'Access denied: only a Master Admin can create Admin or Master Admin users');
  END IF;

  v_salt := extensions.gen_salt('bf');
  v_quick_access_salt := extensions.gen_salt('bf');

  IF p_quick_access_code IS NULL THEN
    v_quick_access_code := lpad(floor(random() * 1000000)::text, 6, '0');
    WHILE EXISTS (
      SELECT 1 FROM public.users
       WHERE extensions.crypt(v_quick_access_code, quick_access_code) = quick_access_code
    ) LOOP
      v_quick_access_code := lpad(floor(random() * 1000000)::text, 6, '0');
    END LOOP;
  ELSE
    v_quick_access_code := p_quick_access_code;
    IF EXISTS (
      SELECT 1 FROM public.users
       WHERE extensions.crypt(v_quick_access_code, quick_access_code) = quick_access_code
    ) THEN
      RETURN json_build_object('success', false, 'message', 'Quick access code already exists');
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM public.users WHERE username = p_username) THEN
    RETURN json_build_object('success', false, 'message', 'Username already exists');
  END IF;

  v_password_hash := extensions.crypt(p_password, v_salt);
  v_quick_access_hash := extensions.crypt(v_quick_access_code, v_quick_access_salt);

  INSERT INTO public.users (
    username, password_hash, salt, quick_access_code, quick_access_salt,
    is_master_admin, is_admin, user_type, branch_id, employee_id, position_id,
    status, is_first_login, failed_login_attempts, created_at, updated_at
  ) VALUES (
    p_username, v_password_hash, v_salt, v_quick_access_hash, v_quick_access_salt,
    COALESCE(p_is_master_admin, false), COALESCE(p_is_admin, false),
    p_user_type::user_type_enum, p_branch_id, p_employee_id, p_position_id,
    'active', true, 0, now(), now()
  ) RETURNING id INTO v_user_id;

  RETURN json_build_object(
    'success', true,
    'user_id', v_user_id,
    'quick_access_code', v_quick_access_code,
    'message', 'User created successfully'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

DROP FUNCTION IF EXISTS public.update_user(uuid, character varying, boolean, boolean, character varying, bigint, uuid, uuid, character varying, text);

CREATE FUNCTION public.update_user(
  p_user_id uuid,
  p_username character varying DEFAULT NULL::character varying,
  p_is_master_admin boolean DEFAULT NULL::boolean,
  p_is_admin boolean DEFAULT NULL::boolean,
  p_user_type character varying DEFAULT NULL::character varying,
  p_branch_id bigint DEFAULT NULL::bigint,
  p_employee_id uuid DEFAULT NULL::uuid,
  p_position_id uuid DEFAULT NULL::uuid,
  p_status character varying DEFAULT NULL::character varying,
  p_avatar text DEFAULT NULL::text,
  p_requesting_user_id uuid DEFAULT NULL::uuid
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER
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

  UPDATE public.users SET
    username = COALESCE(p_username, username),
    is_master_admin = COALESCE(p_is_master_admin, is_master_admin),
    is_admin = COALESCE(p_is_admin, is_admin),
    user_type = CASE WHEN p_user_type IS NULL THEN user_type ELSE p_user_type::user_type_enum END,
    branch_id = COALESCE(p_branch_id, branch_id),
    employee_id = COALESCE(p_employee_id, employee_id),
    position_id = COALESCE(p_position_id, position_id),
    status = COALESCE(p_status, status),
    avatar = COALESCE(p_avatar, avatar),
    updated_at = now()
  WHERE id = p_user_id;

  RETURN json_build_object('success', true, 'message', 'User updated successfully');
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_user(character varying, character varying, boolean, boolean, character varying, bigint, uuid, uuid, character varying, uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_user(uuid, character varying, boolean, boolean, character varying, bigint, uuid, uuid, character varying, text, uuid) TO anon, authenticated, service_role;
