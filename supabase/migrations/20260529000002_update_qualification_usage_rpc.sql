-- Update get_hr_employee_qualification_usage to source leave data from day_off table
-- leave_approved_days: count of approved annual leave days (DRS052 + approved) within active period
-- leave_paid_days:     count of those that HR has marked as paid (is_paid = true)

CREATE OR REPLACE FUNCTION public.get_hr_employee_qualification_usage(
    p_employee_ids text[]
)
RETURNS TABLE (
    employee_id text,
    ticket_issued_count integer,
    leave_approved_days integer,
    leave_paid_days integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    WITH employees AS (
        SELECT DISTINCT e_id::text AS employee_id
        FROM unnest(COALESCE(p_employee_ids, ARRAY[]::text[])) AS e_id
        WHERE e_id IS NOT NULL AND btrim(e_id) <> ''
    ),
    active_ticket_period AS (
        SELECT DISTINCT ON (p.employee_id)
            p.employee_id,
            p.effective_from,
            p.effective_to,
            p.is_infinite
        FROM public.hr_employee_applicability_rule_periods p
        JOIN employees e ON e.employee_id = p.employee_id
        WHERE p.rule_type = 'ticket'
            AND p.effective_from <= CURRENT_DATE
            AND (p.is_infinite = true OR p.effective_to >= CURRENT_DATE)
        ORDER BY p.employee_id, p.effective_from DESC
    ),
    active_leave_period AS (
        SELECT DISTINCT ON (p.employee_id)
            p.employee_id,
            p.effective_from,
            p.effective_to,
            p.is_infinite
        FROM public.hr_employee_applicability_rule_periods p
        JOIN employees e ON e.employee_id = p.employee_id
        WHERE p.rule_type = 'leave_salary'
            AND p.effective_from <= CURRENT_DATE
            AND (p.is_infinite = true OR p.effective_to >= CURRENT_DATE)
        ORDER BY p.employee_id, p.effective_from DESC
    ),
    ticket_usage AS (
        SELECT
            e.employee_id,
            COALESCE(SUM(t.ticket_count), 0)::integer AS ticket_issued_count
        FROM employees e
        LEFT JOIN active_ticket_period ap ON ap.employee_id = e.employee_id
        LEFT JOIN public.hr_employee_ticket_issuances t
            ON t.employee_id = e.employee_id
            AND ap.employee_id IS NOT NULL
            AND t.issuance_date >= ap.effective_from
            AND (ap.is_infinite = true OR t.issuance_date <= ap.effective_to)
        GROUP BY e.employee_id
    ),
    leave_usage AS (
        SELECT
            e.employee_id,
            -- All approved annual leave days (DRS052) within active period
            COALESCE(COUNT(d.id) FILTER (
                WHERE d.day_off_reason_id = 'DRS052'
                  AND d.approval_status = 'approved'
            ), 0)::integer AS leave_approved_days,
            -- Subset the HR has marked as paid
            COALESCE(COUNT(d.id) FILTER (
                WHERE d.day_off_reason_id = 'DRS052'
                  AND d.approval_status = 'approved'
                  AND d.is_paid = true
            ), 0)::integer AS leave_paid_days
        FROM employees e
        LEFT JOIN active_leave_period ap ON ap.employee_id = e.employee_id
        LEFT JOIN public.day_off d
            ON d.employee_id = e.employee_id
            AND ap.employee_id IS NOT NULL
            AND d.day_off_date >= ap.effective_from
            AND (ap.is_infinite = true OR d.day_off_date <= ap.effective_to)
        GROUP BY e.employee_id
    )
    SELECT
        e.employee_id,
        COALESCE(t.ticket_issued_count, 0)  AS ticket_issued_count,
        COALESCE(l.leave_approved_days, 0)  AS leave_approved_days,
        COALESCE(l.leave_paid_days, 0)      AS leave_paid_days
    FROM employees e
    LEFT JOIN ticket_usage t ON t.employee_id = e.employee_id
    LEFT JOIN leave_usage   l ON l.employee_id = e.employee_id
    ORDER BY e.employee_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_hr_employee_qualification_usage(text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_hr_employee_qualification_usage(text[]) TO anon;
