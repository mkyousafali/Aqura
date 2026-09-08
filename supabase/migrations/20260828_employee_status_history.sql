-- Employee status history: replaces the single employment_status /
-- employment_status_effective_date / employment_status_reason columns on
-- hr_employee_master with a proper history table (status + effective_from +
-- effective_to + reason), so status changes over time are queryable, and the
-- current-status columns on hr_employee_master are removed entirely.
--
-- Design (confirmed with the user before building):
--  - Start dates may be past or future, as long as they don't conflict with
--    an existing period for that employee.
--  - Reason is required on every status change.
--  - Closing a record sets effective_to = new_start_date - 1 (non-overlapping,
--    inclusive ranges).
--  - effective_from may be NULL where the true start date is unknown (some
--    legacy employees have no join_date) -- treated as "no known lower
--    bound" (matches any date) everywhere it's read, rather than inventing
--    a date.

-- ============================================================
-- 1. History table
-- ============================================================
CREATE TABLE public.hr_employee_status_history (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id text NOT NULL REFERENCES public.hr_employee_master(id),
    status text NOT NULL,
    effective_from date,
    effective_to date,
    reason text NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    created_by uuid,
    CONSTRAINT hr_employee_status_history_status_chk
        CHECK (status = ANY (ARRAY['Job (With Finger)'::text, 'Remote Job'::text, 'Vacation'::text, 'Resigned'::text])),
    CONSTRAINT hr_employee_status_history_reason_chk
        CHECK (btrim(reason) <> ''),
    CONSTRAINT hr_employee_status_history_range_chk
        CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from)
);

COMMENT ON TABLE public.hr_employee_status_history IS
    'Full history of employment_status changes per employee. Exactly one row per employee has effective_to IS NULL at any time (the currently-open record).';

-- At most one open (current/future) record per employee
CREATE UNIQUE INDEX hr_employee_status_history_one_open_idx
    ON public.hr_employee_status_history (employee_id)
    WHERE effective_to IS NULL;

CREATE INDEX hr_employee_status_history_employee_from_idx
    ON public.hr_employee_status_history (employee_id, effective_from);

ALTER TABLE public.hr_employee_status_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all access to hr_employee_status_history"
    ON public.hr_employee_status_history USING (true) WITH CHECK (true);

-- ============================================================
-- 2. Backfill: one row per employee, current status only
--    - effective_from: existing employment_status_effective_date if set,
--      else join_date, else NULL (unknown -- 34 employees have no join_date)
--    - reason: existing employment_status_reason if set, else a note
-- ============================================================
INSERT INTO public.hr_employee_status_history (employee_id, status, effective_from, effective_to, reason)
SELECT
    id,
    employment_status,
    COALESCE(employment_status_effective_date, join_date),
    NULL,
    COALESCE(NULLIF(btrim(employment_status_reason), ''), 'Backfilled from existing employee record')
FROM public.hr_employee_master;

-- ============================================================
-- 3. "Status as of a given date" + "current status" helpers
-- ============================================================
CREATE FUNCTION public.get_employee_status_as_of(p_employee_id text, p_date date)
RETURNS TABLE(status text, effective_from date, effective_to date, reason text)
LANGUAGE sql STABLE
AS $$
    SELECT h.status, h.effective_from, h.effective_to, h.reason
    FROM public.hr_employee_status_history h
    WHERE h.employee_id = p_employee_id
      AND (h.effective_from IS NULL OR h.effective_from <= p_date)
      AND (h.effective_to IS NULL OR h.effective_to >= p_date)
    ORDER BY h.effective_from DESC NULLS LAST
    LIMIT 1;
$$;

COMMENT ON FUNCTION public.get_employee_status_as_of(text, date) IS
    'Returns the employment status that was/is/will be active for one employee on a given date, per hr_employee_status_history.';

CREATE VIEW public.hr_employee_current_status AS
SELECT DISTINCT ON (h.employee_id)
    h.employee_id,
    h.status AS employment_status,
    h.effective_from AS employment_status_effective_date,
    h.reason AS employment_status_reason
FROM public.hr_employee_status_history h
WHERE (h.effective_from IS NULL OR h.effective_from <= CURRENT_DATE)
  AND (h.effective_to IS NULL OR h.effective_to >= CURRENT_DATE)
ORDER BY h.employee_id, h.effective_from DESC NULLS LAST, h.id DESC;

COMMENT ON VIEW public.hr_employee_current_status IS
    'One row per employee: whichever hr_employee_status_history record covers today. Use this (or hr_employee_master_with_status) instead of a raw employment_status column.';

-- ============================================================
-- 4. change_employee_status: the only way status should ever change.
--    Validates, closes the current/open record, opens the new one.
-- ============================================================
CREATE FUNCTION public.change_employee_status(
    p_employee_id text,
    p_new_status text,
    p_start_date date,
    p_reason text,
    p_created_by uuid DEFAULT NULL
)
RETURNS TABLE(id bigint, employee_id text, status text, effective_from date, effective_to date, reason text)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_valid_statuses text[] := ARRAY['Job (With Finger)', 'Remote Job', 'Vacation', 'Resigned'];
    v_open RECORD;
    v_conflict RECORD;
BEGIN
    IF COALESCE(trim(p_employee_id), '') = '' THEN
        RAISE EXCEPTION 'Employee ID is required';
    END IF;
    IF NOT (p_new_status = ANY(v_valid_statuses)) THEN
        RAISE EXCEPTION 'Invalid employment status value: %', p_new_status;
    END IF;
    IF p_start_date IS NULL THEN
        RAISE EXCEPTION 'Start date is required';
    END IF;
    IF COALESCE(trim(p_reason), '') = '' THEN
        RAISE EXCEPTION 'Reason is required';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.hr_employee_master m WHERE m.id = p_employee_id) THEN
        RAISE EXCEPTION 'Employee not found';
    END IF;

    SELECT h.* INTO v_open
    FROM public.hr_employee_status_history h
    WHERE h.employee_id = p_employee_id AND h.effective_to IS NULL
    LIMIT 1;

    IF v_open.id IS NOT NULL AND v_open.effective_from IS NOT NULL AND p_start_date <= v_open.effective_from THEN
        RAISE EXCEPTION 'New start date must be after % (%), when the current status began', v_open.effective_from, v_open.status;
    END IF;

    SELECT h.* INTO v_conflict
    FROM public.hr_employee_status_history h
    WHERE h.employee_id = p_employee_id
      AND h.effective_to IS NOT NULL
      AND (h.effective_from IS NULL OR h.effective_from <= p_start_date)
      AND h.effective_to >= p_start_date
    LIMIT 1;

    IF v_conflict.id IS NOT NULL THEN
        RAISE EXCEPTION 'This date falls within an existing "%" period (% to %)',
            v_conflict.status, COALESCE(v_conflict.effective_from::text, 'unknown'), v_conflict.effective_to;
    END IF;

    IF v_open.id IS NOT NULL THEN
        UPDATE public.hr_employee_status_history
        SET effective_to = p_start_date - 1
        WHERE hr_employee_status_history.id = v_open.id;
    END IF;

    RETURN QUERY
    INSERT INTO public.hr_employee_status_history (employee_id, status, effective_from, effective_to, reason, created_by)
    VALUES (p_employee_id, p_new_status, p_start_date, NULL, trim(p_reason), p_created_by)
    RETURNING
        hr_employee_status_history.id,
        hr_employee_status_history.employee_id,
        hr_employee_status_history.status,
        hr_employee_status_history.effective_from,
        hr_employee_status_history.effective_to,
        hr_employee_status_history.reason;
END;
$$;

COMMENT ON FUNCTION public.change_employee_status(text, text, date, text, uuid) IS
    'The only supported way to change an employee''s employment_status: validates, closes the current record, opens the new one atomically.';

-- ============================================================
-- 5. Re-point every function that used to read hr_employee_master.employment_status
--    directly, to instead join hr_employee_current_status. Signatures/return
--    columns unchanged except update_employee_master_basic (loses the status
--    param+column entirely -- status changes now go through change_employee_status).
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_break_summary_all_employees(p_date_from date DEFAULT NULL::date, p_date_to date DEFAULT NULL::date, p_branch_id integer DEFAULT NULL::integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_date_from DATE;
    v_date_to DATE;
    v_result JSONB;
BEGIN
    v_date_to := COALESCE(p_date_to, (NOW() AT TIME ZONE 'Asia/Riyadh')::DATE);
    v_date_from := COALESCE(p_date_from, v_date_to - INTERVAL '6 days');

    SELECT COALESCE(jsonb_agg(emp_row ORDER BY emp_row->>'employee_name_en'), '[]'::JSONB)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'employee_id', e.id,
            'employee_name_en', e.name_en,
            'employee_name_ar', e.name_ar,
            'branch_id', e.current_branch_id,
            'days', COALESCE(
                (SELECT jsonb_agg(day_data ORDER BY day_data->>'date')
                 FROM (
                    SELECT jsonb_build_object(
                        'date', d.dt::DATE::TEXT,
                        'total_seconds', COALESCE(SUM(br.duration_seconds), 0),
                        'break_count', COUNT(br.id)
                    ) AS day_data
                    FROM generate_series(v_date_from, v_date_to, '1 day'::INTERVAL) AS d(dt)
                    LEFT JOIN break_register br
                        ON br.user_id = e.user_id
                        AND br.status = 'closed'
                        AND (br.start_time AT TIME ZONE 'Asia/Riyadh')::DATE = d.dt::DATE
                    GROUP BY d.dt
                 ) sub
                ),
                '[]'::JSONB
            ),
            'grand_total_seconds', COALESCE(
                (SELECT SUM(br2.duration_seconds)
                 FROM break_register br2
                 WHERE br2.user_id = e.user_id
                   AND br2.status = 'closed'
                   AND (br2.start_time AT TIME ZONE 'Asia/Riyadh')::DATE BETWEEN v_date_from AND v_date_to
                ), 0
            )
        ) AS emp_row
        FROM hr_employee_master e
        LEFT JOIN hr_employee_current_status s ON s.employee_id = e.id
        WHERE e.user_id IS NOT NULL
          AND COALESCE(s.employment_status, '') NOT IN ('Remote Job', 'Vacation', 'Resigned')
          AND (p_branch_id IS NULL OR e.current_branch_id = p_branch_id)
    ) final;

    RETURN jsonb_build_object(
        'success', true,
        'date_from', v_date_from::TEXT,
        'date_to', v_date_to::TEXT,
        'employees', v_result
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_day_offs_with_details(p_date_from date, p_date_to date) RETURNS TABLE(id text, employee_id text, employee_id_number text, employee_name_en text, employee_name_ar text, employee_email text, employee_whatsapp text, branch_id text, branch_name_en text, branch_name_ar text, branch_location_en text, branch_location_ar text, nationality_id text, nationality_name_en text, nationality_name_ar text, sponsorship_status text, employment_status text, day_off_date date, approval_status text, reason_en text, reason_ar text, document_url text, description text, is_deductible_on_salary boolean, approval_requested_at timestamp with time zone, day_off_reason_id text, approver_name_en text, approver_name_ar text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.id::TEXT,
        d.employee_id::TEXT,
        COALESCE(e.id_number, '')::TEXT AS employee_id_number,
        COALESCE(e.name_en, 'N/A')::TEXT AS employee_name_en,
        COALESCE(e.name_ar, 'N/A')::TEXT AS employee_name_ar,
        COALESCE(e.email, '')::TEXT AS employee_email,
        COALESCE(e.whatsapp_number, '')::TEXT AS employee_whatsapp,
        e.current_branch_id::TEXT AS branch_id,
        COALESCE(b.name_en, 'N/A')::TEXT AS branch_name_en,
        COALESCE(b.name_ar, 'N/A')::TEXT AS branch_name_ar,
        COALESCE(b.location_en, '')::TEXT AS branch_location_en,
        COALESCE(b.location_ar, '')::TEXT AS branch_location_ar,
        e.nationality_id::TEXT,
        COALESCE(n.name_en, 'N/A')::TEXT AS nationality_name_en,
        COALESCE(n.name_ar, 'N/A')::TEXT AS nationality_name_ar,
        e.sponsorship_status::TEXT,
        COALESCE(s.employment_status, '')::TEXT,
        d.day_off_date,
        COALESCE(d.approval_status, 'pending')::TEXT AS approval_status,
        COALESCE(r.reason_en, 'N/A')::TEXT AS reason_en,
        COALESCE(r.reason_ar, 'N/A')::TEXT AS reason_ar,
        d.document_url::TEXT,
        d.description::TEXT,
        COALESCE(d.is_deductible_on_salary, false) AS is_deductible_on_salary,
        d.approval_requested_at,
        d.day_off_reason_id::TEXT,
        COALESCE(a.name_en, '')::TEXT AS approver_name_en,
        COALESCE(a.name_ar, '')::TEXT AS approver_name_ar
    FROM day_off d
    LEFT JOIN hr_employee_master e ON e.id = d.employee_id
    LEFT JOIN hr_employee_current_status s ON s.employee_id = e.id
    LEFT JOIN branches b ON b.id = e.current_branch_id
    LEFT JOIN nationalities n ON n.id = e.nationality_id
    LEFT JOIN day_off_reasons r ON r.id = d.day_off_reason_id
    LEFT JOIN hr_employee_master a ON a.id = d.approval_approved_by::text
    WHERE d.day_off_date >= p_date_from
      AND d.day_off_date <= p_date_to
    ORDER BY d.day_off_date DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_employee_master_list(p_search text DEFAULT ''::text, p_page integer DEFAULT 1, p_limit integer DEFAULT 50, p_status_filter text DEFAULT NULL::text, p_branch_filter integer DEFAULT NULL::integer, p_position_filter uuid DEFAULT NULL::uuid) RETURNS TABLE(id text, name_en character varying, name_ar character varying, current_branch_id integer, branch_name_en character varying, branch_name_ar character varying, branch_location_en character varying, branch_location_ar character varying, current_position_id uuid, position_title_en character varying, position_title_ar character varying, employment_status text, whatsapp_number text, email text, total_count bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    e.id,
    e.name_en,
    e.name_ar,
    e.current_branch_id,
    b.name_en AS branch_name_en,
    b.name_ar AS branch_name_ar,
    b.location_en AS branch_location_en,
    b.location_ar AS branch_location_ar,
    e.current_position_id,
    pos.position_title_en,
    pos.position_title_ar,
    s.employment_status,
    e.whatsapp_number,
    e.email,
    COUNT(*) OVER() AS total_count
  FROM hr_employee_master e
  LEFT JOIN branches b ON b.id = e.current_branch_id
  LEFT JOIN hr_positions pos ON pos.id = e.current_position_id
  LEFT JOIN hr_employee_current_status s ON s.employee_id = e.id
  WHERE
    (COALESCE(p_search, '') = ''
      OR e.name_en ILIKE '%' || p_search || '%'
      OR e.name_ar ILIKE '%' || p_search || '%'
      OR e.id ILIKE '%' || p_search || '%'
      OR e.whatsapp_number ILIKE '%' || p_search || '%'
      OR e.email ILIKE '%' || p_search || '%')
    AND (p_status_filter IS NULL OR p_status_filter = '' OR s.employment_status = p_status_filter)
    AND (p_branch_filter IS NULL OR e.current_branch_id = p_branch_filter)
    AND (p_position_filter IS NULL OR e.current_position_id = p_position_filter)
  ORDER BY e.name_en ASC NULLS LAST
  LIMIT GREATEST(1, LEAST(p_limit, 200))
  OFFSET (GREATEST(1, p_page) - 1) * GREATEST(1, LEAST(p_limit, 200));
$$;

CREATE OR REPLACE FUNCTION public.get_employee_master_list(p_search text DEFAULT ''::text, p_page integer DEFAULT 1, p_limit integer DEFAULT 50, p_status_filter text DEFAULT NULL::text, p_branch_filter integer DEFAULT NULL::integer, p_position_filter uuid DEFAULT NULL::uuid, p_exclude_statuses text[] DEFAULT NULL::text[]) RETURNS TABLE(id text, name_en character varying, name_ar character varying, current_branch_id integer, branch_name_en character varying, branch_name_ar character varying, branch_location_en character varying, branch_location_ar character varying, current_position_id uuid, position_title_en character varying, position_title_ar character varying, employment_status text, whatsapp_number text, email text, total_count bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    e.id, e.name_en, e.name_ar, e.current_branch_id,
    b.name_en AS branch_name_en, b.name_ar AS branch_name_ar,
    b.location_en AS branch_location_en, b.location_ar AS branch_location_ar,
    e.current_position_id, pos.position_title_en, pos.position_title_ar,
    s.employment_status, e.whatsapp_number, e.email,
    COUNT(*) OVER() AS total_count
  FROM hr_employee_master e
  LEFT JOIN branches b ON b.id = e.current_branch_id
  LEFT JOIN hr_positions pos ON pos.id = e.current_position_id
  LEFT JOIN hr_employee_current_status s ON s.employee_id = e.id
  WHERE
    (COALESCE(p_search, '') = ''
      OR e.name_en ILIKE '%' || p_search || '%'
      OR e.name_ar ILIKE '%' || p_search || '%'
      OR e.id ILIKE '%' || p_search || '%'
      OR e.whatsapp_number ILIKE '%' || p_search || '%'
      OR e.email ILIKE '%' || p_search || '%')
    AND (p_status_filter IS NULL OR p_status_filter = '' OR s.employment_status = p_status_filter)
    AND (p_branch_filter IS NULL OR e.current_branch_id = p_branch_filter)
    AND (p_position_filter IS NULL OR e.current_position_id = p_position_filter)
    AND (p_exclude_statuses IS NULL
         OR array_length(p_exclude_statuses, 1) IS NULL
         OR NOT (s.employment_status = ANY(p_exclude_statuses)))
  ORDER BY e.name_en ASC NULLS LAST
  LIMIT GREATEST(1, LEAST(p_limit, 200))
  OFFSET (GREATEST(1, p_page) - 1) * GREATEST(1, LEAST(p_limit, 200));
$$;

CREATE OR REPLACE FUNCTION public.get_hr_dropdown_options() RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT json_build_object(
    'branches', (
      SELECT json_agg(json_build_object(
        'id', id,
        'name_en', name_en,
        'name_ar', name_ar,
        'location_en', location_en,
        'location_ar', location_ar
      ) ORDER BY name_en)
      FROM branches
      WHERE is_active = true
    ),
    'positions', (
      SELECT json_agg(json_build_object(
        'id', id,
        'title_en', position_title_en,
        'title_ar', position_title_ar,
        'department_id', department_id,
        'level_id', level_id
      ) ORDER BY position_title_en)
      FROM hr_positions
      WHERE is_active = true
    ),
    'departments', (
      SELECT json_agg(json_build_object(
        'id', id,
        'name_en', department_name_en,
        'name_ar', department_name_ar
      ) ORDER BY department_name_en)
      FROM hr_departments
      WHERE is_active = true
    ),
    'levels', (
      SELECT json_agg(json_build_object(
        'id', id,
        'name_en', level_name_en,
        'name_ar', level_name_ar,
        'order', level_order
      ) ORDER BY level_order)
      FROM hr_levels
      WHERE is_active = true
    ),
    'employment_statuses', '["Job (With Finger)","Remote Job","Vacation","Resigned"]'::json,
    'all_statuses', '["Job (With Finger)","Remote Job","Vacation","Resigned"]'::json
  );
$$;

CREATE OR REPLACE FUNCTION public.get_hr_employee_applicability(p_limit integer DEFAULT 50, p_offset integer DEFAULT 0, p_name_search text DEFAULT NULL::text, p_nationality_id text DEFAULT NULL::text, p_ticket_enabled boolean DEFAULT NULL::boolean, p_leave_enabled boolean DEFAULT NULL::boolean) RETURNS TABLE(applicability_id bigint, employee_id text, employee_name_en text, employee_name_ar text, nationality_id text, nationality_name_en text, nationality_name_ar text, sponsorship_status boolean, join_date date, employment_status text, ticket_rule_id bigint, ticket_rule_enabled boolean, ticket_rule_name_en text, ticket_rule_name_ar text, qualified_ticket_count integer, ticket_periods_count integer, leave_salary_rule_id bigint, leave_salary_rule_enabled boolean, leave_rule_name_en text, leave_rule_name_ar text, qualified_leave_days integer, leave_periods_count integer, total_count bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    WITH base AS (
        SELECT
            a.id AS applicability_id,
            e.id::text AS employee_id,
            e.name_en::text AS employee_name_en,
            e.name_ar::text AS employee_name_ar,
            e.nationality_id::text AS nationality_id,
            n.name_en::text AS nationality_name_en,
            n.name_ar::text AS nationality_name_ar,
            e.sponsorship_status,
            e.join_date,
            s.employment_status::text AS employment_status,
            COALESCE(tp.rule_id, a.ticket_rule_id) AS ticket_rule_id,
            CASE WHEN tp.rule_id IS NOT NULL THEN true ELSE COALESCE(a.ticket_rule_enabled, false) END AS ticket_rule_enabled,
            COALESCE(tp.rule_name_en, tr.rule_name_en)::text AS ticket_rule_name_en,
            COALESCE(tp.rule_name_ar, tr.rule_name_ar)::text AS ticket_rule_name_ar,
            a.qualified_ticket_count,
            (
                SELECT COUNT(*)::integer
                FROM public.hr_employee_applicability_rule_periods p
                WHERE p.employee_id = e.id
                    AND p.rule_type = 'ticket'
            ) AS ticket_periods_count,
            COALESCE(lp.rule_id, a.leave_salary_rule_id) AS leave_salary_rule_id,
            CASE WHEN lp.rule_id IS NOT NULL THEN true ELSE COALESCE(a.leave_salary_rule_enabled, false) END AS leave_salary_rule_enabled,
            COALESCE(lp.rule_name_en, lr.rule_name_en)::text AS leave_rule_name_en,
            COALESCE(lp.rule_name_ar, lr.rule_name_ar)::text AS leave_rule_name_ar,
            a.qualified_leave_days,
            (
                SELECT COUNT(*)::integer
                FROM public.hr_employee_applicability_rule_periods p
                WHERE p.employee_id = e.id
                    AND p.rule_type = 'leave_salary'
            ) AS leave_periods_count
        FROM public.hr_employee_master e
        LEFT JOIN public.hr_employee_current_status s ON s.employee_id = e.id
        LEFT JOIN public.hr_employee_settlement_applicability a
            ON a.employee_id = e.id
        LEFT JOIN public.nationalities n
            ON n.id = e.nationality_id
        LEFT JOIN public.settlement_rules tr
            ON tr.id = a.ticket_rule_id
        LEFT JOIN public.settlement_rules lr
            ON lr.id = a.leave_salary_rule_id
        LEFT JOIN LATERAL (
            SELECT
                p.rule_id,
                r.rule_name_en,
                r.rule_name_ar
            FROM public.hr_employee_applicability_rule_periods p
            JOIN public.settlement_rules r ON r.id = p.rule_id
            WHERE p.employee_id = e.id
                AND p.rule_type = 'ticket'
                AND p.effective_from <= CURRENT_DATE
                AND (p.is_infinite = true OR p.effective_to >= CURRENT_DATE)
            ORDER BY p.effective_from DESC
            LIMIT 1
        ) tp ON true
        LEFT JOIN LATERAL (
            SELECT
                p.rule_id,
                r.rule_name_en,
                r.rule_name_ar
            FROM public.hr_employee_applicability_rule_periods p
            JOIN public.settlement_rules r ON r.id = p.rule_id
            WHERE p.employee_id = e.id
                AND p.rule_type = 'leave_salary'
                AND p.effective_from <= CURRENT_DATE
                AND (p.is_infinite = true OR p.effective_to >= CURRENT_DATE)
            ORDER BY p.effective_from DESC
            LIMIT 1
        ) lp ON true
        WHERE s.employment_status = ANY (ARRAY['Job (With Finger)', 'Remote Job', 'Vacation'])
    ),
    filtered AS (
        SELECT *
        FROM base b
        WHERE (
                p_name_search IS NULL OR BTRIM(p_name_search) = ''
                OR COALESCE(b.employee_name_en, '') ILIKE '%' || BTRIM(p_name_search) || '%'
                OR COALESCE(b.employee_name_ar, '') ILIKE '%' || BTRIM(p_name_search) || '%'
                OR b.employee_id ILIKE '%' || BTRIM(p_name_search) || '%'
            )
            AND (
                p_nationality_id IS NULL OR BTRIM(p_nationality_id) = ''
                OR b.nationality_id = BTRIM(p_nationality_id)
            )
            AND (
                p_ticket_enabled IS NULL
                OR b.ticket_rule_enabled = p_ticket_enabled
            )
            AND (
                p_leave_enabled IS NULL
                OR b.leave_salary_rule_enabled = p_leave_enabled
            )
    )
    SELECT
        f.applicability_id,
        f.employee_id,
        f.employee_name_en,
        f.employee_name_ar,
        f.nationality_id,
        f.nationality_name_en,
        f.nationality_name_ar,
        f.sponsorship_status,
        f.join_date,
        f.employment_status,
        f.ticket_rule_id,
        f.ticket_rule_enabled,
        f.ticket_rule_name_en,
        f.ticket_rule_name_ar,
        f.qualified_ticket_count,
        f.ticket_periods_count,
        f.leave_salary_rule_id,
        f.leave_salary_rule_enabled,
        f.leave_rule_name_en,
        f.leave_rule_name_ar,
        f.qualified_leave_days,
        f.leave_periods_count,
        COUNT(*) OVER() AS total_count
    FROM filtered f
    ORDER BY
        CASE
            WHEN LOWER(COALESCE(f.nationality_name_en, '')) = 'saudi arabia'
            THEN 0
            ELSE 1
        END,
        f.nationality_name_en NULLS LAST,
        f.employee_name_en
    LIMIT p_limit
    OFFSET p_offset;
$$;

CREATE OR REPLACE FUNCTION public.get_special_shift_date_wise(p_limit integer DEFAULT 50, p_offset integer DEFAULT 0, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date) RETURNS TABLE(id text, employee_id text, employee_name_en text, employee_name_ar text, branch_id text, branch_name_en text, branch_name_ar text, branch_location_en text, branch_location_ar text, nationality_id text, nationality_name_en text, nationality_name_ar text, sponsorship_status boolean, employment_status text, shift_date text, shift_start_time text, shift_start_buffer integer, shift_end_time text, shift_end_buffer integer, is_shift_overlapping_next_day boolean, working_hours numeric, total_count bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT
        v.id::text,
        v.employee_id::text,
        COALESCE(e.name_en, 'N/A')           AS employee_name_en,
        COALESCE(e.name_ar, 'N/A')           AS employee_name_ar,
        e.current_branch_id::text            AS branch_id,
        COALESCE(b.name_en, 'N/A')           AS branch_name_en,
        COALESCE(b.name_ar, 'N/A')           AS branch_name_ar,
        COALESCE(b.location_en, '')          AS branch_location_en,
        COALESCE(b.location_ar, '')          AS branch_location_ar,
        e.nationality_id::text,
        COALESCE(n.name_en, 'N/A')           AS nationality_name_en,
        COALESCE(n.name_ar, 'N/A')           AS nationality_name_ar,
        e.sponsorship_status,
        COALESCE(s.employment_status, '')    AS employment_status,
        v.date_from::text                    AS shift_date,
        sl.shift_start_time::text,
        sl.shift_start_buffer::integer,
        sl.shift_end_time::text,
        sl.shift_end_buffer::integer,
        sl.is_shift_overlapping_next_day,
        sl.working_hours,
        COUNT(*) OVER ()                     AS total_count
    FROM hr_special_shift_date_wise_versions v
    JOIN hr_special_shift_date_wise_slots sl ON sl.version_id = v.id AND sl.slot_order = 1
    LEFT JOIN hr_employee_master e ON e.id = v.employee_id
    LEFT JOIN hr_employee_current_status s ON s.employee_id = e.id
    LEFT JOIN branches           b ON b.id = e.current_branch_id
    LEFT JOIN nationalities      n ON n.id::text = e.nationality_id::text
    WHERE
        (p_start_date IS NULL OR v.date_from >= p_start_date)
        AND (p_end_date IS NULL OR v.date_from <= p_end_date)
    ORDER BY v.date_from DESC
    LIMIT  p_limit
    OFFSET p_offset;
$$;

-- update_employee_master_basic loses the status param/column entirely --
-- signature and return shape change, so DROP + CREATE (not OR REPLACE).
DROP FUNCTION IF EXISTS public.update_employee_master_basic(text, text, text, integer, uuid, text, text, text);

CREATE FUNCTION public.update_employee_master_basic(
    p_id text,
    p_name_en text DEFAULT NULL::text,
    p_name_ar text DEFAULT NULL::text,
    p_current_branch_id integer DEFAULT NULL::integer,
    p_current_position_id uuid DEFAULT NULL::uuid,
    p_whatsapp_number text DEFAULT NULL::text,
    p_email text DEFAULT NULL::text
) RETURNS TABLE(id text, name_en character varying, name_ar character varying, current_branch_id integer, current_position_id uuid, whatsapp_number text, email text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF COALESCE(trim(p_id), '') = '' THEN
    RAISE EXCEPTION 'Employee ID is required';
  END IF;

  IF p_current_branch_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM branches b WHERE b.id = p_current_branch_id) THEN
      RAISE EXCEPTION 'Branch not found';
    END IF;
  END IF;

  IF p_current_position_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM hr_positions pos WHERE pos.id = p_current_position_id) THEN
      RAISE EXCEPTION 'Position not found';
    END IF;
  END IF;

  RETURN QUERY
  UPDATE hr_employee_master e
  SET
    name_en = COALESCE(NULLIF(trim(p_name_en), ''), e.name_en),
    name_ar = COALESCE(NULLIF(trim(p_name_ar), ''), e.name_ar),
    current_branch_id = COALESCE(p_current_branch_id, e.current_branch_id),
    current_position_id = CASE
      WHEN p_current_position_id IS NOT NULL THEN p_current_position_id
      ELSE e.current_position_id
    END,
    whatsapp_number = CASE
      WHEN p_whatsapp_number IS NOT NULL THEN NULLIF(trim(p_whatsapp_number), '')
      ELSE e.whatsapp_number
    END,
    email = CASE
      WHEN p_email IS NOT NULL THEN NULLIF(trim(p_email), '')
      ELSE e.email
    END,
    updated_at = NOW()
  WHERE e.id = p_id
  RETURNING
    e.id,
    e.name_en,
    e.name_ar,
    e.current_branch_id,
    e.current_position_id,
    e.whatsapp_number,
    e.email;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Employee not found';
  END IF;
END;
$$;

-- ============================================================
-- 6. Remove the old columns from hr_employee_master (safe now -- nothing
--    above references them anymore).
-- ============================================================
ALTER TABLE public.hr_employee_master DROP CONSTRAINT IF EXISTS employment_status_values;
DROP INDEX IF EXISTS public.idx_employment_status;
DROP INDEX IF EXISTS public.idx_employment_status_effective_date;

ALTER TABLE public.hr_employee_master
    DROP COLUMN IF EXISTS employment_status,
    DROP COLUMN IF EXISTS employment_status_effective_date,
    DROP COLUMN IF EXISTS employment_status_reason;

-- ============================================================
-- 7. Compatibility view: same column names as before
--    (employment_status / employment_status_effective_date /
--    employment_status_reason), so any read-only consumer can switch its
--    `.from('hr_employee_master')` to `.from('hr_employee_master_with_status')`
--    with no other code changes.
-- ============================================================
CREATE VIEW public.hr_employee_master_with_status AS
SELECT
    m.*,
    s.employment_status,
    s.employment_status_effective_date,
    s.employment_status_reason
FROM public.hr_employee_master m
LEFT JOIN public.hr_employee_current_status s ON s.employee_id = m.id;

COMMENT ON VIEW public.hr_employee_master_with_status IS
    'hr_employee_master plus its current employment_status/effective_date/reason from hr_employee_status_history, for read-only compatibility with old queries.';
