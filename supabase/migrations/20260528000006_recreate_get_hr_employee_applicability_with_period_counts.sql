-- Recreate applicability RPC with period counts and active-period precedence

DROP FUNCTION IF EXISTS public.get_hr_employee_applicability(integer, integer, text, text, boolean, boolean);

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
    ticket_periods_count integer,
    leave_salary_rule_id bigint,
    leave_salary_rule_enabled boolean,
    leave_rule_name_en text,
    leave_rule_name_ar text,
    qualified_leave_days integer,
    leave_periods_count integer,
    total_count bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
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
            e.employment_status::text AS employment_status,
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
        WHERE e.employment_status = ANY (ARRAY['Job (With Finger)', 'Remote Job', 'Vacation'])
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
                OR COALESCE(f.nationality_name_ar, '') LIKE '%السعود%'
            THEN 0
            ELSE 1
        END,
        LOWER(COALESCE(f.employee_name_en, '')),
        f.employee_id
    LIMIT GREATEST(COALESCE(p_limit, 50), 1)
    OFFSET GREATEST(COALESCE(p_offset, 0), 0);
$$;

GRANT EXECUTE ON FUNCTION public.get_hr_employee_applicability(integer, integer, text, text, boolean, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_hr_employee_applicability(integer, integer, text, text, boolean, boolean) TO anon;
