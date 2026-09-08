-- Fixes a permission-write bug and closes a matching gap in the new
-- Salary Statement Edit/Log permissions feature.
--
-- Root cause: newly created tables in this project only get default GRANTs
-- of SELECT for the anon/authenticated roles (this is Supabase's standard,
-- intentional default — see pg_default_acl for the public schema). RLS
-- policies here are all "allow all" (USING (true) WITH CHECK (true)),
-- meaning *row-level* access was never the real gate — the app has always
-- relied on the frontend to check permissions before calling Supabase, with
-- writes going through SECURITY DEFINER RPC functions (e.g.
-- create_salary_statement_log) to bypass the anon role's read-only table
-- grant. button_permissions and the new salary_statement_edit_log_permissions
-- table were instead written to directly via `.from(table).upsert()/.delete()`,
-- which runs as the caller's actual (anon) role and hits "permission denied
-- for table" — never worked from the deployed app.
--
-- Fix: wrap writes to both tables in SECURITY DEFINER RPCs, each re-checking
-- Master Admin server-side (mirroring list_salary_statement_logs), and
-- update the frontend to call these instead of direct table writes.

CREATE FUNCTION public.upsert_button_permission(
    p_requesting_user_id uuid,
    p_target_user_id uuid,
    p_button_code text,
    p_is_enabled boolean
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_is_master_admin boolean;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin
    FROM public.users
    WHERE id = p_requesting_user_id;

    IF NOT COALESCE(v_is_master_admin, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin only');
    END IF;

    INSERT INTO public.button_permissions (user_id, button_code, is_enabled, updated_at)
    VALUES (p_target_user_id, p_button_code, p_is_enabled, now())
    ON CONFLICT (user_id, button_code)
    DO UPDATE SET is_enabled = excluded.is_enabled, updated_at = now();

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

COMMENT ON FUNCTION public.upsert_button_permission(uuid, uuid, text, boolean) IS
    'Master-Admin-only write path for button_permissions, bypassing the anon role''s read-only table grant via SECURITY DEFINER. Used by Button Access Control instead of a direct table upsert.';

CREATE FUNCTION public.upsert_salary_statement_edit_log_permission(
    p_requesting_user_id uuid,
    p_target_user_id uuid,
    p_can_edit boolean,
    p_can_view_logs boolean
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_is_master_admin boolean;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin
    FROM public.users
    WHERE id = p_requesting_user_id;

    IF NOT COALESCE(v_is_master_admin, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin only');
    END IF;

    INSERT INTO public.salary_statement_edit_log_permissions (user_id, can_edit, can_view_logs, granted_by, updated_at)
    VALUES (p_target_user_id, p_can_edit, p_can_view_logs, p_requesting_user_id, now())
    ON CONFLICT (user_id)
    DO UPDATE SET can_edit = excluded.can_edit, can_view_logs = excluded.can_view_logs,
                  granted_by = excluded.granted_by, updated_at = now();

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

COMMENT ON FUNCTION public.upsert_salary_statement_edit_log_permission(uuid, uuid, boolean, boolean) IS
    'Master-Admin-only write path for salary_statement_edit_log_permissions. Used by SalaryStatementPermissionsModal instead of a direct table upsert.';

CREATE FUNCTION public.delete_salary_statement_edit_log_permission(
    p_requesting_user_id uuid,
    p_target_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_is_master_admin boolean;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin
    FROM public.users
    WHERE id = p_requesting_user_id;

    IF NOT COALESCE(v_is_master_admin, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin only');
    END IF;

    DELETE FROM public.salary_statement_edit_log_permissions WHERE user_id = p_target_user_id;

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

COMMENT ON FUNCTION public.delete_salary_statement_edit_log_permission(uuid, uuid) IS
    'Master-Admin-only removal of a user''s Edit/Log grant. Used by SalaryStatementPermissionsModal instead of a direct table delete.';
