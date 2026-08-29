-- Per-user Edit / Log permissions for the Prepare Salary Statement window.
--
-- Distinct from the generic button_permissions table (which only gates
-- whether a user can open the Salary Statement window at all, via the
-- SALARY_STATEMENT button code). This table gates two finer-grained
-- capabilities *inside* that window:
--   - can_edit:      see/use the per-employee Edit button (opens the salary
--                     edit modal).
--   - can_view_logs: see/use the Logs button and audit log modal.
--
-- Master Admin bypasses this table entirely (always has both) — enforced in
-- the frontend, same convention as isButtonAllowed() in Sidebar.svelte.
-- Managed from the "Manage Edit and Log Permission" popup, which only lets a
-- Master Admin choose among users who already hold the SALARY_STATEMENT
-- button permission.

CREATE TABLE public.salary_statement_edit_log_permissions (
    user_id uuid NOT NULL PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    can_edit boolean NOT NULL DEFAULT false,
    can_view_logs boolean NOT NULL DEFAULT false,
    granted_by uuid REFERENCES public.users(id),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.salary_statement_edit_log_permissions IS
    'Per-user Edit / Log capability grants for the Prepare Salary Statement window, managed by Master Admin via the "Manage Edit and Log Permission" popup. Master Admin bypasses this table (always full access), enforced in the frontend.';

ALTER TABLE public.salary_statement_edit_log_permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all access to salary_statement_edit_log_permissions"
    ON public.salary_statement_edit_log_permissions USING (true) WITH CHECK (true);

-- list_salary_statement_logs previously hard-required Master Admin. Widen it
-- to also allow a user explicitly granted can_view_logs in the new table,
-- while still denying everyone else. Body otherwise unchanged from
-- 01_schema.sql.
CREATE OR REPLACE FUNCTION public.list_salary_statement_logs(p_requesting_user_id uuid, p_limit integer DEFAULT 200, p_offset integer DEFAULT 0, p_statement_id uuid DEFAULT NULL::uuid, p_employee_id text DEFAULT NULL::text, p_action_type text DEFAULT NULL::text, p_status text DEFAULT NULL::text, p_user_id_filter uuid DEFAULT NULL::uuid, p_date_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_date_to timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_is_master_admin boolean;
    v_can_view_logs    boolean;
    v_total           int;
    v_rows            jsonb;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin
    FROM public.users
    WHERE id = p_requesting_user_id;

    SELECT can_view_logs INTO v_can_view_logs
    FROM public.salary_statement_edit_log_permissions
    WHERE user_id = p_requesting_user_id;

    IF NOT COALESCE(v_is_master_admin, false) AND NOT COALESCE(v_can_view_logs, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin or Log permission required');
    END IF;

    -- Count total (for pagination)
    SELECT count(*) INTO v_total
    FROM public.salary_statement_logs l
    WHERE
        (p_statement_id   IS NULL OR l.statement_id  = p_statement_id)
        AND (p_employee_id IS NULL OR l.employee_id  = p_employee_id)
        AND (p_action_type IS NULL OR l.action_type  = p_action_type)
        AND (p_status      IS NULL OR l.status        = p_status)
        AND (p_user_id_filter IS NULL OR l.user_id   = p_user_id_filter)
        AND (p_date_from   IS NULL OR l.created_at  >= p_date_from)
        AND (p_date_to     IS NULL OR l.created_at  <= p_date_to);

    -- Fetch page
    SELECT jsonb_agg(row_to_json(q) ORDER BY q.created_at DESC)
    INTO v_rows
    FROM (
        SELECT
            l.id, l.statement_id, l.statement_name,
            l.employee_id, l.employee_name,
            l.user_id, l.user_name, l.user_role,
            l.action_type, l.action_description,
            l.before_value, l.after_value, l.deleted_record,
            l.related_ui, l.status, l.metadata,
            l.created_at
        FROM public.salary_statement_logs l
        WHERE
            (p_statement_id   IS NULL OR l.statement_id  = p_statement_id)
            AND (p_employee_id IS NULL OR l.employee_id  = p_employee_id)
            AND (p_action_type IS NULL OR l.action_type  = p_action_type)
            AND (p_status      IS NULL OR l.status        = p_status)
            AND (p_user_id_filter IS NULL OR l.user_id   = p_user_id_filter)
            AND (p_date_from   IS NULL OR l.created_at  >= p_date_from)
            AND (p_date_to     IS NULL OR l.created_at  <= p_date_to)
        ORDER BY l.created_at DESC
        LIMIT p_limit OFFSET p_offset
    ) q;

    RETURN jsonb_build_object(
        'success', true,
        'total', v_total,
        'items', COALESCE(v_rows, '[]'::jsonb)
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
