-- Access control for the standalone Aqura Cam Checker desktop app
-- (hikvision-player). Master admins always have access; everyone else must
-- be explicitly granted here via the Support App Access window (Controls >
-- Manage > Support App Access, SUPPORT_APP_ACCESS button).
CREATE TABLE IF NOT EXISTS public.cam_checker_access (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    granted_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT cam_checker_access_pkey PRIMARY KEY (id),
    CONSTRAINT cam_checker_access_user_id_key UNIQUE (user_id),
    CONSTRAINT cam_checker_access_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT cam_checker_access_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES public.users(id)
);

CREATE INDEX IF NOT EXISTS idx_cam_checker_access_user_id ON public.cam_checker_access USING btree (user_id);

ALTER TABLE public.cam_checker_access ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cam_checker_access_select ON public.cam_checker_access;
CREATE POLICY cam_checker_access_select ON public.cam_checker_access FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS cam_checker_access_insert ON public.cam_checker_access;
CREATE POLICY cam_checker_access_insert ON public.cam_checker_access FOR INSERT TO authenticated, anon WITH CHECK (true);

DROP POLICY IF EXISTS cam_checker_access_delete ON public.cam_checker_access;
CREATE POLICY cam_checker_access_delete ON public.cam_checker_access FOR DELETE TO authenticated, anon USING (true);

-- List current access grants with display info, for the Support App Access admin table.
CREATE OR REPLACE FUNCTION public.get_cam_checker_access_list()
RETURNS TABLE (
  id uuid,
  user_id uuid,
  username character varying,
  employee_name text,
  granted_by_username character varying,
  created_at timestamp with time zone
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    a.id,
    a.user_id,
    u.username,
    e.name AS employee_name,
    gu.username AS granted_by_username,
    a.created_at
  FROM public.cam_checker_access a
  JOIN public.users u ON u.id = a.user_id
  LEFT JOIN public.hr_employees e ON e.id = u.employee_id
  LEFT JOIN public.users gu ON gu.id = a.granted_by
  ORDER BY a.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_cam_checker_access_list() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_cam_checker_access_list() TO anon;

-- Grant access to one or more users. Restricted to Master Admin or a user
-- holding the SUPPORT_APP_ACCESS button permission (same delegation model
-- as upsert_button_permission).
CREATE OR REPLACE FUNCTION public.grant_cam_checker_access(
    p_requesting_user_id uuid,
    p_user_ids uuid[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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

    INSERT INTO public.cam_checker_access (user_id, granted_by)
    SELECT uid, p_requesting_user_id FROM unnest(p_user_ids) AS uid
    ON CONFLICT (user_id) DO NOTHING;

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.grant_cam_checker_access(uuid, uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.grant_cam_checker_access(uuid, uuid[]) TO anon;

-- Revoke access for a single user. Same authorization rule as the grant function.
CREATE OR REPLACE FUNCTION public.revoke_cam_checker_access(
    p_requesting_user_id uuid,
    p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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

    DELETE FROM public.cam_checker_access WHERE user_id = p_user_id;

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.revoke_cam_checker_access(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_cam_checker_access(uuid, uuid) TO anon;
