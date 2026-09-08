-- ============================================================================
-- Update get_mobile_dashboard_data: read from new hr_ shift tables
-- Update get_special_shift_date_wise: read from new hr_ shift tables
-- ============================================================================

-- 1. Update get_mobile_dashboard_data shift lookups
-- We replace the shift resolution blocks (today + yesterday) to read from hr_*_versions + hr_*_slots
-- using the same priority: date-wise → weekday → regular

CREATE OR REPLACE FUNCTION public.get_mobile_dashboard_data(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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

    -- 3. Get shift info for TODAY (priority: date-wise → weekday → regular) using new hr_ tables
    SELECT COALESCE(
        (SELECT jsonb_build_object(
            'shift_start_time', sl.shift_start_time,
            'shift_end_time', sl.shift_end_time,
            'is_shift_overlapping_next_day', sl.is_shift_overlapping_next_day,
            'source', 'special_shift_date_wise'
        )
        FROM hr_special_shift_date_wise_versions v
        JOIN hr_special_shift_date_wise_slots sl ON sl.version_id = v.id
        WHERE v.employee_id = v_employee_id AND v.date_from = v_today::DATE
        ORDER BY sl.slot_order LIMIT 1),

        (SELECT jsonb_build_object(
            'shift_start_time', sl.shift_start_time,
            'shift_end_time', sl.shift_end_time,
            'is_shift_overlapping_next_day', sl.is_shift_overlapping_next_day,
            'source', 'special_shift_weekday'
        )
        FROM hr_special_shift_weekday_versions v
        JOIN hr_special_shift_weekday_slots sl ON sl.version_id = v.id
        WHERE v.employee_id = v_employee_id AND v.weekday = v_today_weekday
        ORDER BY sl.slot_order LIMIT 1),

        (SELECT jsonb_build_object(
            'shift_start_time', sl.shift_start_time,
            'shift_end_time', sl.shift_end_time,
            'is_shift_overlapping_next_day', sl.is_shift_overlapping_next_day,
            'source', 'regular_shift'
        )
        FROM hr_regular_shift_versions v
        JOIN hr_regular_shift_slots sl ON sl.version_id = v.id
        WHERE v.employee_id = v_employee_id
        ORDER BY sl.slot_order LIMIT 1),

        'null'::JSONB
    ) INTO v_shift_info;

    -- 3b. Get shift info for YESTERDAY (needed for break totals)
    SELECT COALESCE(
        (SELECT jsonb_build_object(
            'shift_start_time', sl.shift_start_time,
            'shift_end_time', sl.shift_end_time,
            'is_shift_overlapping_next_day', sl.is_shift_overlapping_next_day
        )
        FROM hr_special_shift_date_wise_versions v
        JOIN hr_special_shift_date_wise_slots sl ON sl.version_id = v.id
        WHERE v.employee_id = v_employee_id AND v.date_from = v_yesterday::DATE
        ORDER BY sl.slot_order LIMIT 1),

        (SELECT jsonb_build_object(
            'shift_start_time', sl.shift_start_time,
            'shift_end_time', sl.shift_end_time,
            'is_shift_overlapping_next_day', sl.is_shift_overlapping_next_day
        )
        FROM hr_special_shift_weekday_versions v
        JOIN hr_special_shift_weekday_slots sl ON sl.version_id = v.id
        WHERE v.employee_id = v_employee_id AND v.weekday = v_yesterday_weekday
        ORDER BY sl.slot_order LIMIT 1),

        (SELECT jsonb_build_object(
            'shift_start_time', sl.shift_start_time,
            'shift_end_time', sl.shift_end_time,
            'is_shift_overlapping_next_day', sl.is_shift_overlapping_next_day
        )
        FROM hr_regular_shift_versions v
        JOIN hr_regular_shift_slots sl ON sl.version_id = v.id
        WHERE v.employee_id = v_employee_id
        ORDER BY sl.slot_order LIMIT 1),

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
    WHERE user_id = p_user_id AND status = 'completed'
    AND created_at >= (NOW() AT TIME ZONE 'Asia/Riyadh')::DATE;

    SELECT COUNT(*) INTO v_box_in_use
    FROM box_operations
    WHERE user_id = p_user_id AND status = 'in_use';

    -- 6. Get daily checklist assignments and submissions
    SELECT COALESCE(jsonb_agg(a), '[]'::JSONB)
    INTO v_checklist_assignments
    FROM (
        SELECT ca.id, ca.checklist_id, ct.title_en, ct.title_ar, ca.due_date, ca.status
        FROM checklist_assignments ca
        JOIN checklist_templates ct ON ct.id = ca.checklist_id
        WHERE ca.assigned_to = v_employee_id
        AND ca.due_date = v_today::DATE
        ORDER BY ca.created_at DESC
    ) a;

    SELECT COALESCE(jsonb_agg(s), '[]'::JSONB)
    INTO v_checklist_submissions
    FROM (
        SELECT cs.id, cs.checklist_id, ct.title_en, ct.title_ar, cs.submitted_at, cs.status
        FROM checklist_submissions cs
        JOIN checklist_templates ct ON ct.id = cs.checklist_id
        WHERE cs.submitted_by = v_employee_id
        AND cs.submitted_at >= (NOW() AT TIME ZONE 'Asia/Riyadh')::DATE
        ORDER BY cs.submitted_at DESC
    ) s;

    -- 7. Get pending task count
    SELECT COUNT(*) INTO v_pending_tasks
    FROM task_assignments
    WHERE assigned_to = v_employee_id AND status IN ('pending', 'in_progress');

    -- 8. Calculate break totals for today and yesterday
    v_break_total_today := 0;
    v_break_total_yesterday := 0;

    -- Today's breaks
    IF v_shift_info IS NOT NULL AND v_shift_info != 'null'::JSONB THEN
        v_shift_start := v_shift_info->>'shift_start_time';
        v_shift_end := v_shift_info->>'shift_end_time';
        v_shift_overlapping := COALESCE((v_shift_info->>'is_shift_overlapping_next_day')::boolean, false);

        IF v_shift_start IS NOT NULL AND v_shift_end IS NOT NULL THEN
            v_window_start := (v_today || ' ' || v_shift_start)::TIMESTAMPTZ;
            IF v_shift_overlapping THEN
                v_window_end := (((v_today::DATE) + INTERVAL '1 day')::TEXT || ' ' || v_shift_end)::TIMESTAMPTZ;
            ELSE
                v_window_end := (v_today || ' ' || v_shift_end)::TIMESTAMPTZ;
            END IF;

            SELECT COALESCE(SUM(
                EXTRACT(EPOCH FROM (COALESCE(br.end_time, NOW()) - br.start_time))::INTEGER / 60
            ), 0) INTO v_break_total_today
            FROM break_registrations br
            WHERE br.employee_id = v_employee_id
            AND br.start_time >= v_window_start
            AND br.start_time <= v_window_end;
        END IF;
    END IF;

    -- Yesterday's breaks
    IF v_yesterday_shift_info IS NOT NULL AND v_yesterday_shift_info != 'null'::JSONB THEN
        v_shift_start := v_yesterday_shift_info->>'shift_start_time';
        v_shift_end := v_yesterday_shift_info->>'shift_end_time';
        v_shift_overlapping := COALESCE((v_yesterday_shift_info->>'is_shift_overlapping_next_day')::boolean, false);

        IF v_shift_start IS NOT NULL AND v_shift_end IS NOT NULL THEN
            v_window_start := (v_yesterday || ' ' || v_shift_start)::TIMESTAMPTZ;
            IF v_shift_overlapping THEN
                v_window_end := (v_today || ' ' || v_shift_end)::TIMESTAMPTZ;
            ELSE
                v_window_end := (v_yesterday || ' ' || v_shift_end)::TIMESTAMPTZ;
            END IF;

            SELECT COALESCE(SUM(
                EXTRACT(EPOCH FROM (COALESCE(br.end_time, NOW()) - br.start_time))::INTEGER / 60
            ), 0) INTO v_break_total_yesterday
            FROM break_registrations br
            WHERE br.employee_id = v_employee_id
            AND br.start_time >= v_window_start
            AND br.start_time <= v_window_end;
        END IF;
    END IF;

    -- Return combined dashboard data
    RETURN jsonb_build_object(
        'success', true,
        'employee_id', v_employee_id,
        'branch_id', v_employee_branch_id,
        'today', v_today,
        'yesterday', v_yesterday,
        'attendance_today', v_attendance_today,
        'attendance_yesterday', v_attendance_yesterday,
        'shift_info', v_shift_info,
        'yesterday_shift_info', v_yesterday_shift_info,
        'punches', v_punches,
        'box_pending_close', v_box_pending_close,
        'box_completed', v_box_completed,
        'box_in_use', v_box_in_use,
        'checklist_assignments', v_checklist_assignments,
        'checklist_submissions', v_checklist_submissions,
        'pending_tasks', v_pending_tasks,
        'break_total_today', v_break_total_today,
        'break_total_yesterday', v_break_total_yesterday
    );
END;
$function$;


-- 2. Update get_special_shift_date_wise to read from hr_special_shift_date_wise_versions + slots
CREATE OR REPLACE FUNCTION public.get_special_shift_date_wise(
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0,
    p_start_date date DEFAULT NULL,
    p_end_date date DEFAULT NULL
)
RETURNS TABLE(
    id text, employee_id text,
    employee_name_en text, employee_name_ar text,
    branch_id text, branch_name_en text, branch_name_ar text,
    branch_location_en text, branch_location_ar text,
    nationality_id text, nationality_name_en text, nationality_name_ar text,
    sponsorship_status boolean, employment_status text,
    shift_date text,
    shift_start_time text, shift_start_buffer integer,
    shift_end_time text, shift_end_buffer integer,
    is_shift_overlapping_next_day boolean,
    working_hours numeric,
    total_count bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
        COALESCE(e.employment_status, '')    AS employment_status,
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
    LEFT JOIN branches           b ON b.id = e.current_branch_id
    LEFT JOIN nationalities      n ON n.id::text = e.nationality_id::text
    WHERE
        (p_start_date IS NULL OR v.date_from >= p_start_date)
        AND (p_end_date IS NULL OR v.date_from <= p_end_date)
    ORDER BY v.date_from DESC
    LIMIT  p_limit
    OFFSET p_offset;
$function$;
