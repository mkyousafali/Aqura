-- Adds a "Copy From Another User" action to Button Access Control: replace a target user's
-- entire button_permissions set with an exact copy of a source user's rows.
--
-- Same reasoning as upsert_button_permission in 20260828_permission_management_write_rpcs.sql:
-- anon/authenticated only have SELECT on button_permissions at the Postgres grant level, so any
-- direct .delete()/.insert() from the frontend 401s. Writes go through this SECURITY DEFINER RPC,
-- which re-checks Master Admin server-side before touching the table.

CREATE FUNCTION public.copy_button_permissions(
    p_requesting_user_id uuid,
    p_source_user_id uuid,
    p_target_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_is_master_admin boolean;
    v_copied_count integer;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin
    FROM public.users
    WHERE id = p_requesting_user_id;

    IF NOT COALESCE(v_is_master_admin, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin only');
    END IF;

    IF p_source_user_id IS NULL OR p_target_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Source and target user are required');
    END IF;

    IF p_source_user_id = p_target_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Source and target must be different users');
    END IF;

    -- "Exact copy": wipe the target's existing rows first rather than upserting on top of them,
    -- so a button the target had explicitly disabled/enabled that the source has no row for at
    -- all doesn't linger behind after the copy.
    DELETE FROM public.button_permissions WHERE user_id = p_target_user_id;

    INSERT INTO public.button_permissions (user_id, button_code, is_enabled, updated_at)
    SELECT p_target_user_id, button_code, is_enabled, now()
    FROM public.button_permissions
    WHERE user_id = p_source_user_id;

    GET DIAGNOSTICS v_copied_count = ROW_COUNT;

    RETURN jsonb_build_object('success', true, 'copied_count', v_copied_count);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

COMMENT ON FUNCTION public.copy_button_permissions(uuid, uuid, uuid) IS
    'Master-Admin-only: replaces the target user''s entire button_permissions set with an exact copy of the source user''s rows. Used by Button Access Control''s "Copy From Another User" action.';
