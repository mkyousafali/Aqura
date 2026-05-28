-- RPCs for faster applicability management loading and updates

CREATE OR REPLACE FUNCTION public.get_hr_employee_applicability(
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0,
    p_name_search text DEFAULT NULL,
    p_nationality_id text DEFAULT NULL,
    p_ticket_enabled boolean DEFAULT NULL,
    p_leave_enabled boolean DEFAULT NULL
)
RETURNS TABLE (
    applicability_id bigint,
    employee_id text,
    employee_name_en text,
    employee_name_ar text,
    nationality_id text,
    nationality_name_en text,
    nationality_name_ar text,
    sponsorship_status boolean,
    join_date date,
    employment_status text,
    ticket_rule_id bigint,
    ticket_rule_enabled boolean,
    ticket_rule_name_en text,
    ticket_rule_name_ar text,
    qualified_ticket_count integer,
    leave_salary_rule_id bigint,
    leave_salary_rule_enabled boolean,
    leave_rule_name_en text,
    leave_rule_name_ar text,
    qualified_leave_days integer,
    total_count bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    WITH filtered AS (
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
            e.employment_status::text AS employment_status,
            a.ticket_rule_id,
            COALESCE(a.ticket_rule_enabled, false) AS ticket_rule_enabled,
            tr.rule_name_en::text AS ticket_rule_name_en,
            tr.rule_name_ar::text AS ticket_rule_name_ar,
            a.qualified_ticket_count,
            a.leave_salary_rule_id,
            COALESCE(a.leave_salary_rule_enabled, false) AS leave_salary_rule_enabled,
            lr.rule_name_en::text AS leave_rule_name_en,
            lr.rule_name_ar::text AS leave_rule_name_ar,
            a.qualified_leave_days
        FROM public.hr_employee_master e
        LEFT JOIN public.hr_employee_settlement_applicability a
            ON a.employee_id = e.id
        LEFT JOIN public.nationalities n
            ON n.id = e.nationality_id
        LEFT JOIN public.settlement_rules tr
            ON tr.id = a.ticket_rule_id
        LEFT JOIN public.settlement_rules lr
            ON lr.id = a.leave_salary_rule_id
        WHERE e.employment_status = ANY (ARRAY['Job (With Finger)', 'Remote Job', 'Vacation'])
            AND (
                p_name_search IS NULL OR BTRIM(p_name_search) = ''
                OR COALESCE(e.name_en, '') ILIKE '%' || BTRIM(p_name_search) || '%'
                OR COALESCE(e.name_ar, '') ILIKE '%' || BTRIM(p_name_search) || '%'
                OR e.id ILIKE '%' || BTRIM(p_name_search) || '%'
            )
            AND (
                p_nationality_id IS NULL OR BTRIM(p_nationality_id) = ''
                OR e.nationality_id::text = BTRIM(p_nationality_id)
            )
            AND (
                p_ticket_enabled IS NULL
                OR COALESCE(a.ticket_rule_enabled, false) = p_ticket_enabled
            )
            AND (
                p_leave_enabled IS NULL
                OR COALESCE(a.leave_salary_rule_enabled, false) = p_leave_enabled
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
        f.leave_salary_rule_id,
        f.leave_salary_rule_enabled,
        f.leave_rule_name_en,
        f.leave_rule_name_ar,
        f.qualified_leave_days,
        COUNT(*) OVER() AS total_count
    FROM filtered f
    ORDER BY
        CASE
            WHEN LOWER(COALESCE(f.nationality_name_en, '')) = 'saudi arabia'
                OR COALESCE(f.nationality_name_ar, '') LIKE '%السعود%'
            THEN 0
            ELSE 1
        END,
        LOWER(COALESCE(f.employee_name_en, '')),
        f.employee_id
    LIMIT GREATEST(COALESCE(p_limit, 50), 1)
    OFFSET GREATEST(COALESCE(p_offset, 0), 0);
$$;

CREATE OR REPLACE FUNCTION public.get_applicability_nationalities()
RETURNS TABLE (
    id text,
    name_en text,
    name_ar text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        n.id::text,
        n.name_en::text,
        n.name_ar::text
    FROM public.nationalities n
    ORDER BY
        CASE
            WHEN LOWER(COALESCE(n.name_en, '')) = 'saudi arabia'
                OR COALESCE(n.name_ar, '') LIKE '%السعود%'
            THEN 0
            ELSE 1
        END,
        LOWER(COALESCE(n.name_en, '')),
        n.id;
$$;

CREATE OR REPLACE FUNCTION public.upsert_hr_employee_applicability_rule(
    p_employee_id text,
    p_rule_type text,
    p_rule_id bigint DEFAULT NULL,
    p_enabled boolean DEFAULT true
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rule public.settlement_rules%ROWTYPE;
    v_join_date date;
    v_total_months integer;
    v_cycle_months integer;
    v_completed_cycles integer;
    v_qualified integer;
BEGIN
    IF p_employee_id IS NULL OR BTRIM(p_employee_id) = '' THEN
        RAISE EXCEPTION 'p_employee_id is required';
    END IF;

    IF p_rule_type NOT IN ('ticket', 'leave_salary') THEN
        RAISE EXCEPTION 'p_rule_type must be ticket or leave_salary';
    END IF;

    SELECT e.join_date INTO v_join_date
    FROM public.hr_employee_master e
    WHERE e.id = p_employee_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Employee % was not found', p_employee_id;
    END IF;

    INSERT INTO public.hr_employee_settlement_applicability (employee_id)
    VALUES (p_employee_id)
    ON CONFLICT (employee_id) DO NOTHING;

    IF COALESCE(p_enabled, false) = false THEN
        IF p_rule_type = 'ticket' THEN
            UPDATE public.hr_employee_settlement_applicability
            SET
                ticket_rule_id = NULL,
                ticket_rule_enabled = false,
                qualified_ticket_count = NULL
            WHERE employee_id = p_employee_id;
        ELSE
            UPDATE public.hr_employee_settlement_applicability
            SET
                leave_salary_rule_id = NULL,
                leave_salary_rule_enabled = false,
                qualified_leave_days = NULL
            WHERE employee_id = p_employee_id;
        END IF;
        RETURN;
    END IF;

    IF p_rule_id IS NULL THEN
        RAISE EXCEPTION 'p_rule_id is required when enabling';
    END IF;

    SELECT * INTO v_rule
    FROM public.settlement_rules r
    WHERE r.id = p_rule_id
        AND r.rule_type = p_rule_type
        AND r.is_active = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Active settlement rule % of type % was not found', p_rule_id, p_rule_type;
    END IF;

    IF v_join_date IS NULL OR v_join_date > CURRENT_DATE THEN
        v_completed_cycles := 0;
    ELSE
        v_total_months :=
            (EXTRACT(YEAR FROM age(CURRENT_DATE, v_join_date))::int * 12)
            + EXTRACT(MONTH FROM age(CURRENT_DATE, v_join_date))::int;

        v_cycle_months := GREATEST(
            1,
            COALESCE(v_rule.qualification_cycle_value, v_rule.qualification_cycle_years, 1)
            * CASE WHEN COALESCE(v_rule.qualification_cycle_unit, 'year') = 'month' THEN 1 ELSE 12 END
        );

        v_completed_cycles := GREATEST(0, FLOOR(v_total_months::numeric / v_cycle_months)::int);
    END IF;

    IF p_rule_type = 'ticket' THEN
        v_qualified := v_completed_cycles * COALESCE(v_rule.ticket_count, 0);
        INSERT INTO public.hr_employee_settlement_applicability (
            employee_id,
            ticket_rule_id,
            ticket_rule_enabled,
            qualified_ticket_count
        )
        VALUES (
            p_employee_id,
            v_rule.id,
            true,
            v_qualified
        )
        ON CONFLICT (employee_id) DO UPDATE
        SET
            ticket_rule_id = EXCLUDED.ticket_rule_id,
            ticket_rule_enabled = EXCLUDED.ticket_rule_enabled,
            qualified_ticket_count = EXCLUDED.qualified_ticket_count;
    ELSE
        v_qualified := v_completed_cycles * COALESCE(v_rule.entitled_days, 0);
        INSERT INTO public.hr_employee_settlement_applicability (
            employee_id,
            leave_salary_rule_id,
            leave_salary_rule_enabled,
            qualified_leave_days
        )
        VALUES (
            p_employee_id,
            v_rule.id,
            true,
            v_qualified
        )
        ON CONFLICT (employee_id) DO UPDATE
        SET
            leave_salary_rule_id = EXCLUDED.leave_salary_rule_id,
            leave_salary_rule_enabled = EXCLUDED.leave_salary_rule_enabled,
            qualified_leave_days = EXCLUDED.qualified_leave_days;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_hr_employee_applicability(integer, integer, text, text, boolean, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_hr_employee_applicability(integer, integer, text, text, boolean, boolean) TO anon;

GRANT EXECUTE ON FUNCTION public.get_applicability_nationalities() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_applicability_nationalities() TO anon;

GRANT EXECUTE ON FUNCTION public.upsert_hr_employee_applicability_rule(text, text, bigint, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_hr_employee_applicability_rule(text, text, bigint, boolean) TO anon;
