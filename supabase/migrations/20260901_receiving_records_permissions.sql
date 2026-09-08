-- Per-user permissions for the Receiving Records window's Master-Admin-gated
-- actions: editing an already-entered ERP invoice reference (double-click),
-- using the Edit button in the Actions column, and using the Delete button.
--
-- Distinct from the generic button_permissions table (which only gates whether
-- a user can open a window/button at all) and from the existing VENDOR_RECORDS
-- button-code check that already gates the ERP reference double-click edit
-- (kept as-is; this table is an additional grant path, not a replacement).
--
-- Master Admin bypasses this table entirely (always has all three) — enforced
-- in the frontend, same convention as isButtonAllowed() in Sidebar.svelte and
-- salary_statement_edit_log_permissions. Managed from the "Edit Permission"
-- popup in ReceivingRecords.svelte, which only a Master Admin can open.

CREATE TABLE public.receiving_records_permissions (
    user_id uuid NOT NULL PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    can_edit_erp_reference boolean NOT NULL DEFAULT false,
    can_edit_record boolean NOT NULL DEFAULT false,
    can_delete boolean NOT NULL DEFAULT false,
    granted_by uuid REFERENCES public.users(id),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.receiving_records_permissions IS
    'Per-user grants for the Receiving Records window: editing an entered ERP reference (double-click), the Edit button, and the Delete button. Master Admin bypasses this table (always full access), enforced in the frontend. Managed via the "Edit Permission" popup in ReceivingRecords.svelte.';

ALTER TABLE public.receiving_records_permissions ENABLE ROW LEVEL SECURITY;

-- Same convention as every other permissions table in this project: RLS is
-- permissive (the real gate is the Postgres GRANT below, which only allows
-- SELECT for anon/authenticated — writes must go through the SECURITY
-- DEFINER RPCs below).
CREATE POLICY "Allow all access to receiving_records_permissions"
    ON public.receiving_records_permissions USING (true) WITH CHECK (true);

CREATE FUNCTION public.upsert_receiving_records_permission(
    p_requesting_user_id uuid,
    p_target_user_id uuid,
    p_can_edit_erp_reference boolean,
    p_can_edit_record boolean,
    p_can_delete boolean
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

    INSERT INTO public.receiving_records_permissions
        (user_id, can_edit_erp_reference, can_edit_record, can_delete, granted_by, updated_at)
    VALUES
        (p_target_user_id, p_can_edit_erp_reference, p_can_edit_record, p_can_delete, p_requesting_user_id, now())
    ON CONFLICT (user_id)
    DO UPDATE SET
        can_edit_erp_reference = excluded.can_edit_erp_reference,
        can_edit_record = excluded.can_edit_record,
        can_delete = excluded.can_delete,
        granted_by = excluded.granted_by,
        updated_at = now();

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

COMMENT ON FUNCTION public.upsert_receiving_records_permission(uuid, uuid, boolean, boolean, boolean) IS
    'Master-Admin-only write path for receiving_records_permissions, bypassing the anon role''s read-only table grant via SECURITY DEFINER. Used by ReceivingRecordsPermissionsModal instead of a direct table upsert.';

CREATE FUNCTION public.delete_receiving_records_permission(
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

    DELETE FROM public.receiving_records_permissions WHERE user_id = p_target_user_id;

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

COMMENT ON FUNCTION public.delete_receiving_records_permission(uuid, uuid) IS
    'Master-Admin-only removal of a user''s Receiving Records permission grant. Used by ReceivingRecordsPermissionsModal instead of a direct table delete.';

GRANT EXECUTE ON FUNCTION public.upsert_receiving_records_permission(uuid, uuid, boolean, boolean, boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.upsert_receiving_records_permission(uuid, uuid, boolean, boolean, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_receiving_records_permission(uuid, uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.delete_receiving_records_permission(uuid, uuid) TO authenticated;
