-- RPC: Get break summary for all employees (day-wise)
-- Shows all active employees even if they have 0 breaks
-- Returns: employee info + break totals for each day in a date range
-- Used by the Break Register "Total Summary" view

CREATE OR REPLACE FUNCTION get_break_summary_all_employees(
    p_date_from DATE DEFAULT NULL,
    p_date_to DATE DEFAULT NULL,
    p_branch_id INTEGER DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_date_from DATE;
    v_date_to DATE;
    v_result JSONB;
BEGIN
    -- Default to last 7 days if not specified
    v_date_to := COALESCE(p_date_to, (NOW() AT TIME ZONE 'Asia/Riyadh')::DATE);
    v_date_from := COALESCE(p_date_from, v_date_to - INTERVAL '6 days');

    -- Build summary: all active employees LEFT JOINed with break data
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
        WHERE e.user_id IS NOT NULL
          AND (e.employment_status IS NULL OR e.employment_status != 'terminated')
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_break_summary_all_employees(DATE, DATE, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_break_summary_all_employees(DATE, DATE, INTEGER) TO anon;
