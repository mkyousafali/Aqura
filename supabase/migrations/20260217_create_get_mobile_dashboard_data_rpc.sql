-- RPC function to get all mobile dashboard data in a single call
-- Replaces 12+ separate client-side queries with one server-side function
-- Returns: employee info, attendance (today+yesterday), shift info, last 2 punches,
--          box operation counts, checklist assignments, and today's checklist submissions

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
    v_attendance_today JSONB;
    v_attendance_yesterday JSONB;
    v_shift_info JSONB;
    v_punches JSONB;
    v_box_pending_close INTEGER;
    v_box_completed INTEGER;
    v_box_in_use INTEGER;
    v_checklist_assignments JSONB;
    v_checklist_submissions JSONB;
    v_pending_tasks INTEGER;
    v_key TEXT;
    v_val TEXT;
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

    -- 3. Get shift info (priority: date-wise → weekday → regular)
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

    -- 6. Count pending tasks across all task types
    SELECT
        (SELECT COUNT(*) FROM task_assignments WHERE assigned_to_user_id = p_user_id AND status IN ('assigned', 'in_progress', 'pending')) +
        (SELECT COUNT(*) FROM quick_task_assignments WHERE assigned_to_user_id = p_user_id AND status IN ('assigned', 'in_progress', 'pending')) +
        (SELECT COUNT(*) FROM receiving_tasks WHERE assigned_user_id = p_user_id AND task_status IN ('pending', 'in_progress'))
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
        )
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_mobile_dashboard_data(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_mobile_dashboard_data(UUID) TO anon;
