-- Widens upsert_button_permission: a user who has been granted the
-- BUTTON_ACCESS_CONTROL button permission (i.e. can open the Button Access
-- Control screen) may now also actually save changes there, not just view
-- it. Master Admin still always passes regardless. Confirmed with the user
-- — this is a deliberate delegation of real grant authority to whoever the
-- screen itself has been shared with, not just Master Admin.
--
-- Deliberately NOT applied to upsert_salary_statement_edit_log_permission /
-- delete_salary_statement_edit_log_permission — the "Manage Edit and Log
-- Permission" button that fronts those stays Master-Admin-only per the
-- original spec, so those two remain Master-Admin-only as well.
CREATE OR REPLACE FUNCTION public.upsert_button_permission(
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
    v_has_access_control boolean;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin
    FROM public.users
    WHERE id = p_requesting_user_id;

    SELECT is_enabled INTO v_has_access_control
    FROM public.button_permissions
    WHERE user_id = p_requesting_user_id AND button_code = 'BUTTON_ACCESS_CONTROL';

    IF NOT COALESCE(v_is_master_admin, false) AND NOT COALESCE(v_has_access_control, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin or Button Access Control permission required');
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
    'Write path for button_permissions, bypassing the anon role''s read-only table grant via SECURITY DEFINER. Callable by Master Admin or any user holding the BUTTON_ACCESS_CONTROL button permission.';
