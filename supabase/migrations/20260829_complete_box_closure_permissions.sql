-- Permitted Closures: controls who may click "Start Closing" on a Complete
-- Box, per branch. Deliberately has NO Master Admin / Admin bypass — per
-- the user's explicit instruction, admins must be granted permission just
-- like anyone else to start closing a box. (This is unlike every other
-- permission gate built this session, which all bypass for Master Admin —
-- this one is intentionally different.)
--
-- Two independent grants per user:
--   - all_branches_enabled: may close boxes at any branch.
--   - complete_box_closure_branch_grants: explicit per-branch grants, used
--     when all_branches_enabled is false. A user's own assigned branch is
--     auto-granted the first time an approver opens their branch list.

CREATE TABLE public.complete_box_closure_permissions (
    user_id uuid NOT NULL PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    all_branches_enabled boolean NOT NULL DEFAULT false,
    branch_specific_enabled boolean NOT NULL DEFAULT false,
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_by uuid REFERENCES public.users(id)
);

COMMENT ON TABLE public.complete_box_closure_permissions IS
    'Per-user closure-permission master switches for Complete Box. all_branches_enabled grants every branch; otherwise complete_box_closure_branch_grants governs which specific branches. No Master Admin/Admin bypass — deliberately checked for every user including admins.';

CREATE TABLE public.complete_box_closure_branch_grants (
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    branch_id integer NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
    granted_by uuid REFERENCES public.users(id),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, branch_id)
);

COMMENT ON TABLE public.complete_box_closure_branch_grants IS
    'Explicit per-branch closure grants for a user, used when complete_box_closure_permissions.all_branches_enabled is false.';

ALTER TABLE public.complete_box_closure_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complete_box_closure_branch_grants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all access to complete_box_closure_permissions"
    ON public.complete_box_closure_permissions USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to complete_box_closure_branch_grants"
    ON public.complete_box_closure_branch_grants USING (true) WITH CHECK (true);

-- ============================================================
-- Write RPCs (Master-Admin-only) — same convention as
-- upsert_button_permission / upsert_complete_box_approver: anon/authenticated
-- only have SELECT on new tables by default, so writes go through a
-- SECURITY DEFINER function that re-checks Master Admin server-side.
-- ============================================================

CREATE FUNCTION public.upsert_complete_box_closure_permission(
    p_requesting_user_id uuid,
    p_target_user_id uuid,
    p_all_branches_enabled boolean DEFAULT NULL,
    p_branch_specific_enabled boolean DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_is_master_admin boolean;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin FROM public.users WHERE id = p_requesting_user_id;
    IF NOT COALESCE(v_is_master_admin, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin only');
    END IF;

    INSERT INTO public.complete_box_closure_permissions (user_id, all_branches_enabled, branch_specific_enabled, updated_by, updated_at)
    VALUES (p_target_user_id, COALESCE(p_all_branches_enabled, false), COALESCE(p_branch_specific_enabled, false), p_requesting_user_id, now())
    ON CONFLICT (user_id) DO UPDATE SET
        all_branches_enabled = COALESCE(p_all_branches_enabled, public.complete_box_closure_permissions.all_branches_enabled),
        branch_specific_enabled = COALESCE(p_branch_specific_enabled, public.complete_box_closure_permissions.branch_specific_enabled),
        updated_by = p_requesting_user_id,
        updated_at = now();

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

CREATE FUNCTION public.set_complete_box_closure_branch_grant(
    p_requesting_user_id uuid,
    p_target_user_id uuid,
    p_branch_id integer,
    p_granted boolean
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_is_master_admin boolean;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin FROM public.users WHERE id = p_requesting_user_id;
    IF NOT COALESCE(v_is_master_admin, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin only');
    END IF;

    IF p_granted THEN
        INSERT INTO public.complete_box_closure_branch_grants (user_id, branch_id, granted_by)
        VALUES (p_target_user_id, p_branch_id, p_requesting_user_id)
        ON CONFLICT (user_id, branch_id) DO NOTHING;
    ELSE
        DELETE FROM public.complete_box_closure_branch_grants
        WHERE user_id = p_target_user_id AND branch_id = p_branch_id;
    END IF;

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Ensures a user's own assigned branch has a grant row, without requiring
-- Master Admin to click it manually — called the first time their branch
-- list is opened. Still Master-Admin-gated since it's a write.
CREATE FUNCTION public.ensure_own_branch_closure_grant(
    p_requesting_user_id uuid,
    p_target_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_is_master_admin boolean;
    v_branch_id integer;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin FROM public.users WHERE id = p_requesting_user_id;
    IF NOT COALESCE(v_is_master_admin, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin only');
    END IF;

    SELECT branch_id INTO v_branch_id FROM public.users WHERE id = p_target_user_id;
    IF v_branch_id IS NULL THEN
        RETURN jsonb_build_object('success', true, 'branch_id', null);
    END IF;

    INSERT INTO public.complete_box_closure_branch_grants (user_id, branch_id, granted_by)
    VALUES (p_target_user_id, v_branch_id, p_requesting_user_id)
    ON CONFLICT (user_id, branch_id) DO NOTHING;

    RETURN jsonb_build_object('success', true, 'branch_id', v_branch_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ============================================================
-- Enforcement check — read-only, callable by anyone (anon has SELECT by
-- default anyway; wrapping it in a function just keeps the two-table OR
-- logic in one place). No Master Admin/Admin bypass, by design.
-- ============================================================
CREATE FUNCTION public.can_user_close_branch(p_user_id uuid, p_branch_id integer)
RETURNS boolean
LANGUAGE sql STABLE
SET search_path TO 'public'
AS $$
    SELECT COALESCE(
        (SELECT all_branches_enabled FROM public.complete_box_closure_permissions WHERE user_id = p_user_id),
        false
    )
    OR (
        COALESCE((SELECT branch_specific_enabled FROM public.complete_box_closure_permissions WHERE user_id = p_user_id), false)
        AND EXISTS (
            SELECT 1 FROM public.complete_box_closure_branch_grants
            WHERE user_id = p_user_id AND branch_id = p_branch_id
        )
    );
$$;
