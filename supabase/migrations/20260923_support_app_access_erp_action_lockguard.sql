-- Adds per-app access allow-lists for three support apps, mirroring the existing
-- live cam_checker_access table/RPC pattern exactly (see SupportAppAccess.svelte,
-- grant_cam_checker_access / revoke_cam_checker_access / get_cam_checker_access_list).
-- These three apps' "Coming Soon" tabs in SupportAppAccess.svelte get real backing tables.

-- ---------------------------------------------------------------------------
-- Aqura Erp Psd Manager
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.erp_psd_manager_access (
    id uuid NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id uuid NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
    granted_by uuid REFERENCES public.users(id),
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_erp_psd_manager_access_user_id ON public.erp_psd_manager_access(user_id);
ALTER TABLE public.erp_psd_manager_access ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS erp_psd_manager_access_select ON public.erp_psd_manager_access;
DROP POLICY IF EXISTS erp_psd_manager_access_insert ON public.erp_psd_manager_access;
DROP POLICY IF EXISTS erp_psd_manager_access_delete ON public.erp_psd_manager_access;
CREATE POLICY erp_psd_manager_access_select ON public.erp_psd_manager_access FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY erp_psd_manager_access_insert ON public.erp_psd_manager_access FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY erp_psd_manager_access_delete ON public.erp_psd_manager_access FOR DELETE TO anon, authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Aqura Action Sync
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.action_sync_access (
    id uuid NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id uuid NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
    granted_by uuid REFERENCES public.users(id),
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_action_sync_access_user_id ON public.action_sync_access(user_id);
ALTER TABLE public.action_sync_access ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS action_sync_access_select ON public.action_sync_access;
DROP POLICY IF EXISTS action_sync_access_insert ON public.action_sync_access;
DROP POLICY IF EXISTS action_sync_access_delete ON public.action_sync_access;
CREATE POLICY action_sync_access_select ON public.action_sync_access FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY action_sync_access_insert ON public.action_sync_access FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY action_sync_access_delete ON public.action_sync_access FOR DELETE TO anon, authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Aqura PC Lock Guard
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pc_lock_guard_access (
    id uuid NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id uuid NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
    granted_by uuid REFERENCES public.users(id),
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pc_lock_guard_access_user_id ON public.pc_lock_guard_access(user_id);
ALTER TABLE public.pc_lock_guard_access ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pc_lock_guard_access_select ON public.pc_lock_guard_access;
DROP POLICY IF EXISTS pc_lock_guard_access_insert ON public.pc_lock_guard_access;
DROP POLICY IF EXISTS pc_lock_guard_access_delete ON public.pc_lock_guard_access;
CREATE POLICY pc_lock_guard_access_select ON public.pc_lock_guard_access FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY pc_lock_guard_access_insert ON public.pc_lock_guard_access FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY pc_lock_guard_access_delete ON public.pc_lock_guard_access FOR DELETE TO anon, authenticated USING (true);

-- ---------------------------------------------------------------------------
-- RPCs — one grant / revoke / list trio per app, identical shape and
-- authorization rule to grant_cam_checker_access / revoke_cam_checker_access /
-- get_cam_checker_access_list (Master Admin OR SUPPORT_APP_ACCESS button holder).
-- ---------------------------------------------------------------------------

-- Erp Psd Manager
DROP FUNCTION IF EXISTS public.get_erp_psd_manager_access_list();
CREATE OR REPLACE FUNCTION public.get_erp_psd_manager_access_list()
RETURNS TABLE(id uuid, user_id uuid, username character varying, employee_name text, granted_by_username character varying, created_at timestamptz)
LANGUAGE sql SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT a.id, a.user_id, u.username, e.name AS employee_name, gu.username AS granted_by_username, a.created_at
  FROM public.erp_psd_manager_access a
  JOIN public.users u ON u.id = a.user_id
  LEFT JOIN public.hr_employees e ON e.id = u.employee_id
  LEFT JOIN public.users gu ON gu.id = a.granted_by
  ORDER BY a.created_at DESC;
$$;

DROP FUNCTION IF EXISTS public.grant_erp_psd_manager_access(uuid, uuid[]);
CREATE OR REPLACE FUNCTION public.grant_erp_psd_manager_access(p_requesting_user_id uuid, p_user_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
    v_is_master_admin boolean;
    v_has_access boolean;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin FROM public.users WHERE id = p_requesting_user_id;
    SELECT is_enabled INTO v_has_access FROM public.button_permissions
      WHERE user_id = p_requesting_user_id AND button_code = 'SUPPORT_APP_ACCESS';

    IF NOT COALESCE(v_is_master_admin, false) AND NOT COALESCE(v_has_access, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin or Support App Access permission required');
    END IF;

    INSERT INTO public.erp_psd_manager_access (user_id, granted_by)
    SELECT uid, p_requesting_user_id FROM unnest(p_user_ids) AS uid
    ON CONFLICT (user_id) DO NOTHING;

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

DROP FUNCTION IF EXISTS public.revoke_erp_psd_manager_access(uuid, uuid);
CREATE OR REPLACE FUNCTION public.revoke_erp_psd_manager_access(p_requesting_user_id uuid, p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
    v_is_master_admin boolean;
    v_has_access boolean;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin FROM public.users WHERE id = p_requesting_user_id;
    SELECT is_enabled INTO v_has_access FROM public.button_permissions
      WHERE user_id = p_requesting_user_id AND button_code = 'SUPPORT_APP_ACCESS';

    IF NOT COALESCE(v_is_master_admin, false) AND NOT COALESCE(v_has_access, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin or Support App Access permission required');
    END IF;

    DELETE FROM public.erp_psd_manager_access WHERE user_id = p_user_id;

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Action Sync
DROP FUNCTION IF EXISTS public.get_action_sync_access_list();
CREATE OR REPLACE FUNCTION public.get_action_sync_access_list()
RETURNS TABLE(id uuid, user_id uuid, username character varying, employee_name text, granted_by_username character varying, created_at timestamptz)
LANGUAGE sql SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT a.id, a.user_id, u.username, e.name AS employee_name, gu.username AS granted_by_username, a.created_at
  FROM public.action_sync_access a
  JOIN public.users u ON u.id = a.user_id
  LEFT JOIN public.hr_employees e ON e.id = u.employee_id
  LEFT JOIN public.users gu ON gu.id = a.granted_by
  ORDER BY a.created_at DESC;
$$;

DROP FUNCTION IF EXISTS public.grant_action_sync_access(uuid, uuid[]);
CREATE OR REPLACE FUNCTION public.grant_action_sync_access(p_requesting_user_id uuid, p_user_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
    v_is_master_admin boolean;
    v_has_access boolean;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin FROM public.users WHERE id = p_requesting_user_id;
    SELECT is_enabled INTO v_has_access FROM public.button_permissions
      WHERE user_id = p_requesting_user_id AND button_code = 'SUPPORT_APP_ACCESS';

    IF NOT COALESCE(v_is_master_admin, false) AND NOT COALESCE(v_has_access, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin or Support App Access permission required');
    END IF;

    INSERT INTO public.action_sync_access (user_id, granted_by)
    SELECT uid, p_requesting_user_id FROM unnest(p_user_ids) AS uid
    ON CONFLICT (user_id) DO NOTHING;

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

DROP FUNCTION IF EXISTS public.revoke_action_sync_access(uuid, uuid);
CREATE OR REPLACE FUNCTION public.revoke_action_sync_access(p_requesting_user_id uuid, p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
    v_is_master_admin boolean;
    v_has_access boolean;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin FROM public.users WHERE id = p_requesting_user_id;
    SELECT is_enabled INTO v_has_access FROM public.button_permissions
      WHERE user_id = p_requesting_user_id AND button_code = 'SUPPORT_APP_ACCESS';

    IF NOT COALESCE(v_is_master_admin, false) AND NOT COALESCE(v_has_access, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin or Support App Access permission required');
    END IF;

    DELETE FROM public.action_sync_access WHERE user_id = p_user_id;

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- PC Lock Guard
DROP FUNCTION IF EXISTS public.get_pc_lock_guard_access_list();
CREATE OR REPLACE FUNCTION public.get_pc_lock_guard_access_list()
RETURNS TABLE(id uuid, user_id uuid, username character varying, employee_name text, granted_by_username character varying, created_at timestamptz)
LANGUAGE sql SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT a.id, a.user_id, u.username, e.name AS employee_name, gu.username AS granted_by_username, a.created_at
  FROM public.pc_lock_guard_access a
  JOIN public.users u ON u.id = a.user_id
  LEFT JOIN public.hr_employees e ON e.id = u.employee_id
  LEFT JOIN public.users gu ON gu.id = a.granted_by
  ORDER BY a.created_at DESC;
$$;

DROP FUNCTION IF EXISTS public.grant_pc_lock_guard_access(uuid, uuid[]);
CREATE OR REPLACE FUNCTION public.grant_pc_lock_guard_access(p_requesting_user_id uuid, p_user_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
    v_is_master_admin boolean;
    v_has_access boolean;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin FROM public.users WHERE id = p_requesting_user_id;
    SELECT is_enabled INTO v_has_access FROM public.button_permissions
      WHERE user_id = p_requesting_user_id AND button_code = 'SUPPORT_APP_ACCESS';

    IF NOT COALESCE(v_is_master_admin, false) AND NOT COALESCE(v_has_access, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin or Support App Access permission required');
    END IF;

    INSERT INTO public.pc_lock_guard_access (user_id, granted_by)
    SELECT uid, p_requesting_user_id FROM unnest(p_user_ids) AS uid
    ON CONFLICT (user_id) DO NOTHING;

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

DROP FUNCTION IF EXISTS public.revoke_pc_lock_guard_access(uuid, uuid);
CREATE OR REPLACE FUNCTION public.revoke_pc_lock_guard_access(p_requesting_user_id uuid, p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
    v_is_master_admin boolean;
    v_has_access boolean;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin FROM public.users WHERE id = p_requesting_user_id;
    SELECT is_enabled INTO v_has_access FROM public.button_permissions
      WHERE user_id = p_requesting_user_id AND button_code = 'SUPPORT_APP_ACCESS';

    IF NOT COALESCE(v_is_master_admin, false) AND NOT COALESCE(v_has_access, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin or Support App Access permission required');
    END IF;

    DELETE FROM public.pc_lock_guard_access WHERE user_id = p_user_id;

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Grants (mirrors cam_checker_access RPC grants: authenticated + anon, since these
-- desktop apps and the admin web UI both call through the anon-key PostgREST client)
GRANT EXECUTE ON FUNCTION public.get_erp_psd_manager_access_list() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.grant_erp_psd_manager_access(uuid, uuid[]) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.revoke_erp_psd_manager_access(uuid, uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_action_sync_access_list() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.grant_action_sync_access(uuid, uuid[]) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.revoke_action_sync_access(uuid, uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_pc_lock_guard_access_list() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.grant_pc_lock_guard_access(uuid, uuid[]) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.revoke_pc_lock_guard_access(uuid, uuid) TO authenticated, anon;
