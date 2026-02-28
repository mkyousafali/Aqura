-- Update get_mobile_dashboard_data RPC to include shift-aware break totals
-- Adds: break_totals.today_seconds, break_totals.yesterday_seconds
-- Uses shift tables (priority: special_shift_date_wise → special_shift_weekday → regular_shift)
-- to determine the correct time window for "today" and "yesterday" breaks

CREATE OR REPLACE FUNCTION get_mobile_dashboard_data(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_employee_id TEXT;
    v_employee_branch_id INTEGER;
    v_employee_id_mapping JSONB;
    v_all_employee_codes TEXT[];
    v_today TEXT;
    v_yesterday TEXT;
    v_today_weekday INTEGER;
    v_yesterday_weekday INTEGER;
    v_attendance_today JSONB;
    v_attendance_yesterday JSONB;
    v_shift_info JSONB;
    v_yesterday_shift_info JSONB;
    v_punches JSONB;
    v_box_pending_close INTEGER;
    v_box_completed INTEGER;
    v_box_in_use INTEGER;
    v_checklist_assignments JSONB;
    v_checklist_submissions JSONB;
    v_pending_tasks INTEGER;
    v_key TEXT;
    v_val TEXT;
    -- Break totals
    v_break_total_today INTEGER;
    v_break_total_yesterday INTEGER;
    v_shift_start TEXT;
    v_shift_end TEXT;
    v_shift_overlapping BOOLEAN;
    v_window_start TIMESTAMPTZ;
    v_window_end TIMESTAMPTZ;
BEGIN
    -- 1. Get employee record
    SELECT id, current_branch_id, employee_id_mapping
    INTO v_employee_id, v_employee_branch_id, v_employee_id_mapping
    FROM hr_employee_master
    WHERE user_id = p_user_id
    LIMIT 1;

    IF v_employee_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Employee record not found');
    END IF;

    -- Extract all employee codes from mapping
    IF v_employee_id_mapping IS NOT NULL THEN
        SELECT array_agg(value::TEXT)
        INTO v_all_employee_codes
        FROM jsonb_each_text(v_employee_id_mapping);
    END IF;

    -- Clean up quotes from employee codes
    IF v_all_employee_codes IS NOT NULL THEN
        v_all_employee_codes := array(
            SELECT trim(both '"' from unnest(v_all_employee_codes))
        );
    END IF;

    -- Calculate dates (Saudi timezone)
    v_today := (NOW() AT TIME ZONE 'Asia/Riyadh')::DATE::TEXT;
    v_yesterday := ((NOW() AT TIME ZONE 'Asia/Riyadh')::DATE - INTERVAL '1 day')::DATE::TEXT;
    v_today_weekday := EXTRACT(DOW FROM (NOW() AT TIME ZONE 'Asia/Riyadh')::DATE)::INTEGER;
    v_yesterday_weekday := EXTRACT(DOW FROM ((NOW() AT TIME ZONE 'Asia/Riyadh')::DATE - INTERVAL '1 day'))::INTEGER;

    -- 2. Get attendance data (today + yesterday)
    SELECT COALESCE(
        (SELECT to_jsonb(a.*) FROM hr_analysed_attendance_data a
         WHERE a.employee_id = v_employee_id AND a.shift_date = v_today::DATE
         LIMIT 1),
        'null'::JSONB
    ) INTO v_attendance_today;

    SELECT COALESCE(
        (SELECT to_jsonb(a.*) FROM hr_analysed_attendance_data a
         WHERE a.employee_id = v_employee_id AND a.shift_date = v_yesterday::DATE
         LIMIT 1),
        'null'::JSONB
    ) INTO v_attendance_yesterday;

    -- 3. Get shift info for TODAY (priority: date-wise → weekday → regular)
    SELECT COALESCE(
        (SELECT jsonb_build_object(
            'shift_start_time', s.shift_start_time,
            'shift_end_time', s.shift_end_time,
            'is_shift_overlapping_next_day', s.is_shift_overlapping_next_day,
            'source', 'special_shift_date_wise'
        )
        FROM special_shift_date_wise s
        WHERE s.employee_id = v_employee_id AND s.shift_date = v_today::DATE
        LIMIT 1),

        (SELECT jsonb_build_object(
            'shift_start_time', s.shift_start_time,
            'shift_end_time', s.shift_end_time,
            'is_shift_overlapping_next_day', s.is_shift_overlapping_next_day,
            'source', 'special_shift_weekday'
        )
        FROM special_shift_weekday s
        WHERE s.employee_id = v_employee_id AND s.weekday = v_today_weekday
        LIMIT 1),

        (SELECT jsonb_build_object(
            'shift_start_time', s.shift_start_time,
            'shift_end_time', s.shift_end_time,
            'is_shift_overlapping_next_day', s.is_shift_overlapping_next_day,
            'source', 'regular_shift'
        )
        FROM regular_shift s
        WHERE s.id = v_employee_id
        LIMIT 1),

        'null'::JSONB
    ) INTO v_shift_info;

    -- 3b. Get shift info for YESTERDAY (needed for break totals)
    SELECT COALESCE(
        (SELECT jsonb_build_object(
            'shift_start_time', s.shift_start_time,
            'shift_end_time', s.shift_end_time,
            'is_shift_overlapping_next_day', s.is_shift_overlapping_next_day
        )
        FROM special_shift_date_wise s
        WHERE s.employee_id = v_employee_id AND s.shift_date = v_yesterday::DATE
        LIMIT 1),

        (SELECT jsonb_build_object(
            'shift_start_time', s.shift_start_time,
            'shift_end_time', s.shift_end_time,
            'is_shift_overlapping_next_day', s.is_shift_overlapping_next_day
        )
        FROM special_shift_weekday s
        WHERE s.employee_id = v_employee_id AND s.weekday = v_yesterday_weekday
        LIMIT 1),

        (SELECT jsonb_build_object(
            'shift_start_time', s.shift_start_time,
            'shift_end_time', s.shift_end_time,
            'is_shift_overlapping_next_day', s.is_shift_overlapping_next_day
        )
        FROM regular_shift s
        WHERE s.id = v_employee_id
        LIMIT 1),

        'null'::JSONB
    ) INTO v_yesterday_shift_info;

    -- 4. Get last 2 fingerprint punches
    IF v_all_employee_codes IS NOT NULL AND array_length(v_all_employee_codes, 1) > 0 THEN
        SELECT COALESCE(jsonb_agg(p), '[]'::JSONB)
        INTO v_punches
        FROM (
            SELECT employee_id, date, time, status
            FROM hr_fingerprint_transactions
            WHERE employee_id = ANY(v_all_employee_codes)
            ORDER BY date DESC, time DESC
            LIMIT 2
        ) p;
    ELSE
        v_punches := '[]'::JSONB;
    END IF;

    -- 5. Get box operation counts
    SELECT COUNT(*) INTO v_box_pending_close
    FROM box_operations
    WHERE user_id = p_user_id AND status = 'pending_close';

    SELECT COUNT(*) INTO v_box_completed
    FROM box_operations
    WHERE user_id = p_user_id AND status = 'completed';

    SELECT COUNT(*) INTO v_box_in_use
    FROM box_operations
    WHERE user_id = p_user_id AND status = 'in_use';

    -- 6. Count pending tasks across all task types (exclude completed and cancelled only)
    SELECT
        (SELECT COUNT(*) FROM task_assignments WHERE assigned_to_user_id = p_user_id AND status NOT IN ('completed', 'cancelled')) +
        (SELECT COUNT(*) FROM quick_task_assignments WHERE assigned_to_user_id = p_user_id AND status NOT IN ('completed', 'cancelled')) +
        (SELECT COUNT(*) FROM receiving_tasks WHERE assigned_user_id = p_user_id AND task_status NOT IN ('completed', 'cancelled'))
    INTO v_pending_tasks;

    -- 7. Get checklist assignments (active, not deleted)
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', ca.id,
        'frequency_type', ca.frequency_type,
        'day_of_week', ca.day_of_week,
        'checklist_id', ca.checklist_id
    )), '[]'::JSONB)
    INTO v_checklist_assignments
    FROM employee_checklist_assignments ca
    WHERE ca.assigned_to_user_id = p_user_id::TEXT
      AND ca.deleted_at IS NULL
      AND ca.is_active = true;

    -- 8. Get today's checklist submissions
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'checklist_id', co.checklist_id
    )), '[]'::JSONB)
    INTO v_checklist_submissions
    FROM hr_checklist_operations co
    WHERE co.employee_id = v_employee_id::VARCHAR
      AND co.operation_date = v_today::DATE;

    -- 9. Calculate TODAY's break total (shift-aware)
    v_break_total_today := 0;
    IF v_shift_info IS NOT NULL AND v_shift_info != 'null'::JSONB THEN
        v_shift_start := v_shift_info->>'shift_start_time';
        v_shift_end := v_shift_info->>'shift_end_time';
        v_shift_overlapping := COALESCE((v_shift_info->>'is_shift_overlapping_next_day')::BOOLEAN, false);

        IF v_shift_overlapping THEN
            -- Overlapping shift: e.g. 20:00 today → 08:00 tomorrow
            v_window_start := (v_today::DATE + v_shift_start::TIME) AT TIME ZONE 'Asia/Riyadh';
            v_window_end := ((v_today::DATE + INTERVAL '1 day') + v_shift_end::TIME) AT TIME ZONE 'Asia/Riyadh';
        ELSE
            -- Normal shift: e.g. 08:00 today → 17:00 today
            v_window_start := (v_today::DATE + v_shift_start::TIME) AT TIME ZONE 'Asia/Riyadh';
            v_window_end := (v_today::DATE + v_shift_end::TIME) AT TIME ZONE 'Asia/Riyadh';
        END IF;

        SELECT COALESCE(SUM(duration_seconds), 0) INTO v_break_total_today
        FROM break_register
        WHERE user_id = p_user_id
          AND status = 'closed'
          AND start_time >= v_window_start
          AND start_time < v_window_end;
    ELSE
        -- No shift info: fallback to calendar day (Saudi timezone)
        SELECT COALESCE(SUM(duration_seconds), 0) INTO v_break_total_today
        FROM break_register
        WHERE user_id = p_user_id
          AND status = 'closed'
          AND start_time >= (v_today::DATE AT TIME ZONE 'Asia/Riyadh')
          AND start_time < ((v_today::DATE + INTERVAL '1 day') AT TIME ZONE 'Asia/Riyadh');
    END IF;

    -- 10. Calculate YESTERDAY's break total (shift-aware, using yesterday's shift)
    v_break_total_yesterday := 0;
    IF v_yesterday_shift_info IS NOT NULL AND v_yesterday_shift_info != 'null'::JSONB THEN
        v_shift_start := v_yesterday_shift_info->>'shift_start_time';
        v_shift_end := v_yesterday_shift_info->>'shift_end_time';
        v_shift_overlapping := COALESCE((v_yesterday_shift_info->>'is_shift_overlapping_next_day')::BOOLEAN, false);

        IF v_shift_overlapping THEN
            -- Overlapping shift: e.g. 20:00 yesterday → 08:00 today
            v_window_start := (v_yesterday::DATE + v_shift_start::TIME) AT TIME ZONE 'Asia/Riyadh';
            v_window_end := (v_today::DATE + v_shift_end::TIME) AT TIME ZONE 'Asia/Riyadh';
        ELSE
            -- Normal shift: e.g. 08:00 yesterday → 17:00 yesterday
            v_window_start := (v_yesterday::DATE + v_shift_start::TIME) AT TIME ZONE 'Asia/Riyadh';
            v_window_end := (v_yesterday::DATE + v_shift_end::TIME) AT TIME ZONE 'Asia/Riyadh';
        END IF;

        SELECT COALESCE(SUM(duration_seconds), 0) INTO v_break_total_yesterday
        FROM break_register
        WHERE user_id = p_user_id
          AND status = 'closed'
          AND start_time >= v_window_start
          AND start_time < v_window_end;
    ELSE
        -- No shift info: fallback to calendar day (Saudi timezone)
        SELECT COALESCE(SUM(duration_seconds), 0) INTO v_break_total_yesterday
        FROM break_register
        WHERE user_id = p_user_id
          AND status = 'closed'
          AND start_time >= (v_yesterday::DATE AT TIME ZONE 'Asia/Riyadh')
          AND start_time < (v_today::DATE AT TIME ZONE 'Asia/Riyadh');
    END IF;

    -- Return everything
    RETURN jsonb_build_object(
        'success', true,
        'employee', jsonb_build_object(
            'id', v_employee_id,
            'branch_id', v_employee_branch_id,
            'employee_codes', to_jsonb(v_all_employee_codes)
        ),
        'attendance', jsonb_build_object(
            'today', v_attendance_today,
            'yesterday', v_attendance_yesterday
        ),
        'shift_info', v_shift_info,
        'punches', v_punches,
        'pending_tasks', v_pending_tasks,
        'box_counts', jsonb_build_object(
            'pending_close', v_box_pending_close,
            'completed', v_box_completed,
            'in_use', v_box_in_use
        ),
        'checklists', jsonb_build_object(
            'assignments', v_checklist_assignments,
            'submissions_today', v_checklist_submissions
        ),
        'break_totals', jsonb_build_object(
            'today_seconds', v_break_total_today,
            'yesterday_seconds', v_break_total_yesterday
        )
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_mobile_dashboard_data(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_mobile_dashboard_data(UUID) TO anon;
