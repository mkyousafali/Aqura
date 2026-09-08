 CREATE OR REPLACE FUNCTION public.get_mobile_dashboard_data(p_user_id uuid)                                                                 +
  RETURNS jsonb                                                                                                                              +
  LANGUAGE plpgsql                                                                                                                           +
  SECURITY DEFINER                                                                                                                           +
 AS $function$\r                                                                                                                             +
 DECLARE\r                                                                                                                                   +
     v_employee_id TEXT;\r                                                                                                                   +
     v_employee_branch_id INTEGER;\r                                                                                                         +
     v_employee_id_mapping JSONB;\r                                                                                                          +
     v_all_employee_codes TEXT[];\r                                                                                                          +
     v_today TEXT;\r                                                                                                                         +
     v_yesterday TEXT;\r                                                                                                                     +
     v_today_weekday INTEGER;\r                                                                                                              +
     v_yesterday_weekday INTEGER;\r                                                                                                          +
     v_attendance_today JSONB;\r                                                                                                             +
     v_attendance_yesterday JSONB;\r                                                                                                         +
     v_shift_info JSONB;\r                                                                                                                   +
     v_yesterday_shift_info JSONB;\r                                                                                                         +
     v_punches JSONB;\r                                                                                                                      +
     v_box_pending_close INTEGER;\r                                                                                                          +
     v_box_completed INTEGER;\r                                                                                                              +
     v_box_in_use INTEGER;\r                                                                                                                 +
     v_checklist_assignments JSONB;\r                                                                                                        +
     v_checklist_submissions JSONB;\r                                                                                                        +
     v_pending_tasks INTEGER;\r                                                                                                              +
     v_key TEXT;\r                                                                                                                           +
     v_val TEXT;\r                                                                                                                           +
     -- Break totals\r                                                                                                                       +
     v_break_total_today INTEGER;\r                                                                                                          +
     v_break_total_yesterday INTEGER;\r                                                                                                      +
     v_shift_start TEXT;\r                                                                                                                   +
     v_shift_end TEXT;\r                                                                                                                     +
     v_shift_overlapping BOOLEAN;\r                                                                                                          +
     v_window_start TIMESTAMPTZ;\r                                                                                                           +
     v_window_end TIMESTAMPTZ;\r                                                                                                             +
 BEGIN\r                                                                                                                                     +
     -- 1. Get employee record\r                                                                                                             +
     SELECT id, current_branch_id, employee_id_mapping\r                                                                                     +
     INTO v_employee_id, v_employee_branch_id, v_employee_id_mapping\r                                                                       +
     FROM hr_employee_master\r                                                                                                               +
     WHERE user_id = p_user_id\r                                                                                                             +
     LIMIT 1;\r                                                                                                                              +
 \r                                                                                                                                          +
     IF v_employee_id IS NULL THEN\r                                                                                                         +
         RETURN jsonb_build_object('success', false, 'error', 'Employee record not found');\r                                                +
     END IF;\r                                                                                                                               +
 \r                                                                                                                                          +
     -- Extract all employee codes from mapping\r                                                                                            +
     IF v_employee_id_mapping IS NOT NULL THEN\r                                                                                             +
         SELECT array_agg(value::TEXT)\r                                                                                                     +
         INTO v_all_employee_codes\r                                                                                                         +
         FROM jsonb_each_text(v_employee_id_mapping);\r                                                                                      +
     END IF;\r                                                                                                                               +
 \r                                                                                                                                          +
     -- Clean up quotes from employee codes\r                                                                                                +
     IF v_all_employee_codes IS NOT NULL THEN\r                                                                                              +
         v_all_employee_codes := array(\r                                                                                                    +
             SELECT trim(both '"' from unnest(v_all_employee_codes))\r                                                                       +
         );\r                                                                                                                                +
     END IF;\r                                                                                                                               +
 \r                                                                                                                                          +
     -- Calculate dates (Saudi timezone)\r                                                                                                   +
     v_today := (NOW() AT TIME ZONE 'Asia/Riyadh')::DATE::TEXT;\r                                                                            +
     v_yesterday := ((NOW() AT TIME ZONE 'Asia/Riyadh')::DATE - INTERVAL '1 day')::DATE::TEXT;\r                                             +
     v_today_weekday := EXTRACT(DOW FROM (NOW() AT TIME ZONE 'Asia/Riyadh')::DATE)::INTEGER;\r                                               +
     v_yesterday_weekday := EXTRACT(DOW FROM ((NOW() AT TIME ZONE 'Asia/Riyadh')::DATE - INTERVAL '1 day'))::INTEGER;\r                      +
 \r                                                                                                                                          +
     -- 2. Get attendance data (today + yesterday)\r                                                                                         +
     SELECT COALESCE(\r                                                                                                                      +
         (SELECT to_jsonb(a.*) FROM hr_analysed_attendance_data a\r                                                                          +
          WHERE a.employee_id = v_employee_id AND a.shift_date = v_today::DATE\r                                                             +
          LIMIT 1),\r                                                                                                                        +
         'null'::JSONB\r                                                                                                                     +
     ) INTO v_attendance_today;\r                                                                                                            +
 \r                                                                                                                                          +
     SELECT COALESCE(\r                                                                                                                      +
         (SELECT to_jsonb(a.*) FROM hr_analysed_attendance_data a\r                                                                          +
          WHERE a.employee_id = v_employee_id AND a.shift_date = v_yesterday::DATE\r                                                         +
          LIMIT 1),\r                                                                                                                        +
         'null'::JSONB\r                                                                                                                     +
     ) INTO v_attendance_yesterday;\r                                                                                                        +
 \r                                                                                                                                          +
     -- 3. Get shift info for TODAY (priority: date-wise ΓåÆ weekday ΓåÆ regular)\r                                                              +
     SELECT COALESCE(\r                                                                                                                      +
         (SELECT jsonb_build_object(\r                                                                                                       +
             'shift_start_time', s.shift_start_time,\r                                                                                       +
             'shift_end_time', s.shift_end_time,\r                                                                                           +
             'is_shift_overlapping_next_day', s.is_shift_overlapping_next_day,\r                                                             +
             'source', 'special_shift_date_wise'\r                                                                                           +
         )\r                                                                                                                                 +
         FROM special_shift_date_wise s\r                                                                                                    +
         WHERE s.employee_id = v_employee_id AND s.shift_date = v_today::DATE\r                                                              +
         LIMIT 1),\r                                                                                                                         +
 \r                                                                                                                                          +
         (SELECT jsonb_build_object(\r                                                                                                       +
             'shift_start_time', s.shift_start_time,\r                                                                                       +
             'shift_end_time', s.shift_end_time,\r                                                                                           +
             'is_shift_overlapping_next_day', s.is_shift_overlapping_next_day,\r                                                             +
             'source', 'special_shift_weekday'\r                                                                                             +
         )\r                                                                                                                                 +
         FROM special_shift_weekday s\r                                                                                                      +
         WHERE s.employee_id = v_employee_id AND s.weekday = v_today_weekday\r                                                               +
         LIMIT 1),\r                                                                                                                         +
 \r                                                                                                                                          +
         (SELECT jsonb_build_object(\r                                                                                                       +
             'shift_start_time', s.shift_start_time,\r                                                                                       +
             'shift_end_time', s.shift_end_time,\r                                                                                           +
             'is_shift_overlapping_next_day', s.is_shift_overlapping_next_day,\r                                                             +
             'source', 'regular_shift'\r                                                                                                     +
         )\r                                                                                                                                 +
         FROM regular_shift s\r                                                                                                              +
         WHERE s.id = v_employee_id\r                                                                                                        +
         LIMIT 1),\r                                                                                                                         +
 \r                                                                                                                                          +
         'null'::JSONB\r                                                                                                                     +
     ) INTO v_shift_info;\r                                                                                                                  +
 \r                                                                                                                                          +
     -- 3b. Get shift info for YESTERDAY (needed for break totals)\r                                                                         +
     SELECT COALESCE(\r                                                                                                                      +
         (SELECT jsonb_build_object(\r                                                                                                       +
             'shift_start_time', s.shift_start_time,\r                                                                                       +
             'shift_end_time', s.shift_end_time,\r                                                                                           +
             'is_shift_overlapping_next_day', s.is_shift_overlapping_next_day\r                                                              +
         )\r                                                                                                                                 +
         FROM special_shift_date_wise s\r                                                                                                    +
         WHERE s.employee_id = v_employee_id AND s.shift_date = v_yesterday::DATE\r                                                          +
         LIMIT 1),\r                                                                                                                         +
 \r                                                                                                                                          +
         (SELECT jsonb_build_object(\r                                                                                                       +
             'shift_start_time', s.shift_start_time,\r                                                                                       +
             'shift_end_time', s.shift_end_time,\r                                                                                           +
             'is_shift_overlapping_next_day', s.is_shift_overlapping_next_day\r                                                              +
         )\r                                                                                                                                 +
         FROM special_shift_weekday s\r                                                                                                      +
         WHERE s.employee_id = v_employee_id AND s.weekday = v_yesterday_weekday\r                                                           +
         LIMIT 1),\r                                                                                                                         +
 \r                                                                                                                                          +
         (SELECT jsonb_build_object(\r                                                                                                       +
             'shift_start_time', s.shift_start_time,\r                                                                                       +
             'shift_end_time', s.shift_end_time,\r                                                                                           +
             'is_shift_overlapping_next_day', s.is_shift_overlapping_next_day\r                                                              +
         )\r                                                                                                                                 +
         FROM regular_shift s\r                                                                                                              +
         WHERE s.id = v_employee_id\r                                                                                                        +
         LIMIT 1),\r                                                                                                                         +
 \r                                                                                                                                          +
         'null'::JSONB\r                                                                                                                     +
     ) INTO v_yesterday_shift_info;\r                                                                                                        +
 \r                                                                                                                                          +
     -- 4. Get last 2 fingerprint punches\r                                                                                                  +
     IF v_all_employee_codes IS NOT NULL AND array_length(v_all_employee_codes, 1) > 0 THEN\r                                                +
         SELECT COALESCE(jsonb_agg(p), '[]'::JSONB)\r                                                                                        +
         INTO v_punches\r                                                                                                                    +
         FROM (\r                                                                                                                            +
             SELECT employee_id, date, time, status\r                                                                                        +
             FROM hr_fingerprint_transactions\r                                                                                              +
             WHERE employee_id = ANY(v_all_employee_codes)\r                                                                                 +
             ORDER BY date DESC, time DESC\r                                                                                                 +
             LIMIT 2\r                                                                                                                       +
         ) p;\r                                                                                                                              +
     ELSE\r                                                                                                                                  +
         v_punches := '[]'::JSONB;\r                                                                                                         +
     END IF;\r                                                                                                                               +
 \r                                                                                                                                          +
     -- 5. Get box operation counts\r                                                                                                        +
     SELECT COUNT(*) INTO v_box_pending_close\r                                                                                              +
     FROM box_operations\r                                                                                                                   +
     WHERE user_id = p_user_id AND status = 'pending_close';\r                                                                               +
 \r                                                                                                                                          +
     SELECT COUNT(*) INTO v_box_completed\r                                                                                                  +
     FROM box_operations\r                                                                                                                   +
     WHERE user_id = p_user_id AND status = 'completed';\r                                                                                   +
 \r                                                                                                                                          +
     SELECT COUNT(*) INTO v_box_in_use\r                                                                                                     +
     FROM box_operations\r                                                                                                                   +
     WHERE user_id = p_user_id AND status = 'in_use';\r                                                                                      +
 \r                                                                                                                                          +
     -- 6. Count pending tasks across all task types (exclude completed and cancelled only)\r                                                +
     SELECT\r                                                                                                                                +
         (SELECT COUNT(*) FROM task_assignments WHERE assigned_to_user_id = p_user_id AND status NOT IN ('completed', 'cancelled')) +\r      +
         (SELECT COUNT(*) FROM quick_task_assignments WHERE assigned_to_user_id = p_user_id AND status NOT IN ('completed', 'cancelled')) +\r+
         (SELECT COUNT(*) FROM receiving_tasks WHERE assigned_user_id = p_user_id AND task_status NOT IN ('completed', 'cancelled'))\r       +
     INTO v_pending_tasks;\r                                                                                                                 +
 \r                                                                                                                                          +
     -- 7. Get checklist assignments (active, not deleted)\r                                                                                 +
     SELECT COALESCE(jsonb_agg(jsonb_build_object(\r                                                                                         +
         'id', ca.id,\r                                                                                                                      +
         'frequency_type', ca.frequency_type,\r                                                                                              +
         'day_of_week', ca.day_of_week,\r                                                                                                    +
         'checklist_id', ca.checklist_id\r                                                                                                   +
     )), '[]'::JSONB)\r                                                                                                                      +
     INTO v_checklist_assignments\r                                                                                                          +
     FROM employee_checklist_assignments ca\r                                                                                                +
     WHERE ca.assigned_to_user_id = p_user_id::TEXT\r                                                                                        +
       AND ca.deleted_at IS NULL\r                                                                                                           +
       AND ca.is_active = true;\r                                                                                                            +
 \r                                                                                                                                          +
     -- 8. Get today's checklist submissions\r                                                                                               +
     SELECT COALESCE(jsonb_agg(jsonb_build_object(\r                                                                                         +
         'checklist_id', co.checklist_id\r                                                                                                   +
     )), '[]'::JSONB)\r                                                                                                                      +
     INTO v_checklist_submissions\r                                                                                                          +
     FROM hr_checklist_operations co\r                                                                                                       +
     WHERE co.employee_id = v_employee_id::VARCHAR\r                                                                                         +
       AND co.operation_date = v_today::DATE;\r                                                                                              +
 \r                                                                                                                                          +
     -- 9. Calculate TODAY's break total (shift-aware)\r                                                                                     +
     v_break_total_today := 0;\r                                                                                                             +
     IF v_shift_info IS NOT NULL AND v_shift_info != 'null'::JSONB THEN\r                                                                    +
         v_shift_start := v_shift_info->>'shift_start_time';\r                                                                               +
         v_shift_end := v_shift_info->>'shift_end_time';\r                                                                                   +
         v_shift_overlapping := COALESCE((v_shift_info->>'is_shift_overlapping_next_day')::BOOLEAN, false);\r                                +
 \r                                                                                                                                          +
         IF v_shift_overlapping THEN\r                                                                                                       +
             -- Overlapping shift: e.g. 20:00 today ΓåÆ 08:00 tomorrow\r                                                                       +
             v_window_start := (v_today::DATE + v_shift_start::TIME) AT TIME ZONE 'Asia/Riyadh';\r                                           +
             v_window_end := ((v_today::DATE + INTERVAL '1 day') + v_shift_end::TIME) AT TIME ZONE 'Asia/Riyadh';\r                          +
         ELSE\r                                                                                                                              +
             -- Normal shift: e.g. 08:00 today ΓåÆ 17:00 today\r                                                                               +
             v_window_start := (v_today::DATE + v_shift_start::TIME) AT TIME ZONE 'Asia/Riyadh';\r                                           +
             v_window_end := (v_today::DATE + v_shift_end::TIME) AT TIME ZONE 'Asia/Riyadh';\r                                               +
         END IF;\r                                                                                                                           +
 \r                                                                                                                                          +
         SELECT COALESCE(SUM(duration_seconds), 0) INTO v_break_total_today\r                                                                +
         FROM break_register\r                                                                                                               +
         WHERE user_id = p_user_id\r                                                                                                         +
           AND status = 'closed'\r                                                                                                           +
           AND start_time >= v_window_start\r                                                                                                +
           AND start_time < v_window_end;\r                                                                                                  +
     ELSE\r                                                                                                                                  +
         -- No shift info: fallback to calendar day (Saudi timezone)\r                                                                       +
         SELECT COALESCE(SUM(duration_seconds), 0) INTO v_break_total_today\r                                                                +
         FROM break_register\r                                                                                                               +
         WHERE user_id = p_user_id\r                                                                                                         +
           AND status = 'closed'\r                                                                                                           +
           AND start_time >= (v_today::DATE AT TIME ZONE 'Asia/Riyadh')\r                                                                    +
           AND start_time < ((v_today::DATE + INTERVAL '1 day') AT TIME ZONE 'Asia/Riyadh');\r                                               +
     END IF;\r                                                                                                                               +
 \r                                                                                                                                          +
     -- 10. Calculate YESTERDAY's break total (shift-aware, using yesterday's shift)\r                                                       +
     v_break_total_yesterday := 0;\r                                                                                                         +
     IF v_yesterday_shift_info IS NOT NULL AND v_yesterday_shift_info != 'null'::JSONB THEN\r                                                +
         v_shift_start := v_yesterday_shift_info->>'shift_start_time';\r                                                                     +
         v_shift_end := v_yesterday_shift_info->>'shift_end_time';\r                                                                         +
         v_shift_overlapping := COALESCE((v_yesterday_shift_info->>'is_shift_overlapping_next_day')::BOOLEAN, false);\r                      +
 \r                                                                                                                                          +
         IF v_shift_overlapping THEN\r                                                                                                       +
             -- Overlapping shift: e.g. 20:00 yesterday ΓåÆ 08:00 today\r                                                                      +
             v_window_start := (v_yesterday::DATE + v_shift_start::TIME) AT TIME ZONE 'Asia/Riyadh';\r                                       +
             v_window_end := (v_today::DATE + v_shift_end::TIME) AT TIME ZONE 'Asia/Riyadh';\r                                               +
         ELSE\r                                                                                                                              +
             -- Normal shift: e.g. 08:00 yesterday ΓåÆ 17:00 yesterday\r                                                                       +
             v_window_start := (v_yesterday::DATE + v_shift_start::TIME) AT TIME ZONE 'Asia/Riyadh';\r                                       +
             v_window_end := (v_yesterday::DATE + v_shift_end::TIME) AT TIME ZONE 'Asia/Riyadh';\r                                           +
         END IF;\r                                                                                                                           +
 \r                                                                                                                                          +
         SELECT COALESCE(SUM(duration_seconds), 0) INTO v_break_total_yesterday\r                                                            +
         FROM break_register\r                                                                                                               +
         WHERE user_id = p_user_id\r                                                                                                         +
           AND status = 'closed'\r                                                                                                           +
           AND start_time >= v_window_start\r                                                                                                +
           AND start_time < v_window_end;\r                                                                                                  +
     ELSE\r                                                                                                                                  +
         -- No shift info: fallback to calendar day (Saudi timezone)\r                                                                       +
         SELECT COALESCE(SUM(duration_seconds), 0) INTO v_break_total_yesterday\r                                                            +
         FROM break_register\r                                                                                                               +
         WHERE user_id = p_user_id\r                                                                                                         +
           AND status = 'closed'\r                                                                                                           +
           AND start_time >= (v_yesterday::DATE AT TIME ZONE 'Asia/Riyadh')\r                                                                +
           AND start_time < (v_today::DATE AT TIME ZONE 'Asia/Riyadh');\r                                                                    +
     END IF;\r                                                                                                                               +
 \r                                                                                                                                          +
     -- Return everything\r                                                                                                                  +
     RETURN jsonb_build_object(\r                                                                                                            +
         'success', true,\r                                                                                                                  +
         'employee', jsonb_build_object(\r                                                                                                   +
             'id', v_employee_id,\r                                                                                                          +
             'branch_id', v_employee_branch_id,\r                                                                                            +
             'employee_codes', to_jsonb(v_all_employee_codes)\r                                                                              +
         ),\r                                                                                                                                +
         'attendance', jsonb_build_object(\r                                                                                                 +
             'today', v_attendance_today,\r                                                                                                  +
             'yesterday', v_attendance_yesterday\r                                                                                           +
         ),\r                                                                                                                                +
         'shift_info', v_shift_info,\r                                                                                                       +
         'punches', v_punches,\r                                                                                                             +
         'pending_tasks', v_pending_tasks,\r                                                                                                 +
         'box_counts', jsonb_build_object(\r                                                                                                 +
             'pending_close', v_box_pending_close,\r                                                                                         +
             'completed', v_box_completed,\r                                                                                                 +
             'in_use', v_box_in_use\r                                                                                                        +
         ),\r                                                                                                                                +
         'checklists', jsonb_build_object(\r                                                                                                 +
             'assignments', v_checklist_assignments,\r                                                                                       +
             'submissions_today', v_checklist_submissions\r                                                                                  +
         ),\r                                                                                                                                +
         'break_totals', jsonb_build_object(\r                                                                                               +
             'today_seconds', v_break_total_today,\r                                                                                         +
             'yesterday_seconds', v_break_total_yesterday\r                                                                                  +
         )\r                                                                                                                                 +
     );\r                                                                                                                                    +
 \r                                                                                                                                          +
 EXCEPTION WHEN OTHERS THEN\r                                                                                                                +
     RETURN jsonb_build_object('success', false, 'error', SQLERRM);\r                                                                        +
 END;\r                                                                                                                                      +
 $function$                                                                                                                                  +
 

 CREATE OR REPLACE FUNCTION public.get_special_shift_date_wise(p_limit integer DEFAULT 50, p_offset integer DEFAULT 0, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date)                                                                                                                                                                                                                                                                                                                                      +
  RETURNS TABLE(id text, employee_id text, employee_name_en text, employee_name_ar text, branch_id text, branch_name_en text, branch_name_ar text, branch_location_en text, branch_location_ar text, nationality_id text, nationality_name_en text, nationality_name_ar text, sponsorship_status boolean, employment_status text, shift_date text, shift_start_time text, shift_start_buffer integer, shift_end_time text, shift_end_buffer integer, is_shift_overlapping_next_day boolean, working_hours numeric, total_count bigint)+
  LANGUAGE sql                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        +
  SECURITY DEFINER                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    +
  SET search_path TO 'public'                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         +
 AS $function$\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      +
     SELECT\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         +
         s.id::text,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                +
         s.employee_id::text,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       +
         COALESCE(e.name_en, 'N/A')           AS employee_name_en,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                  +
         COALESCE(e.name_ar, 'N/A')           AS employee_name_ar,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                  +
         e.current_branch_id::text            AS branch_id,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                         +
         COALESCE(b.name_en, 'N/A')           AS branch_name_en,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                    +
         COALESCE(b.name_ar, 'N/A')           AS branch_name_ar,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                    +
         COALESCE(b.location_en, '')          AS branch_location_en,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                +
         COALESCE(b.location_ar, '')          AS branch_location_ar,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                +
         e.nationality_id::text,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    +
         COALESCE(n.name_en, 'N/A')           AS nationality_name_en,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                               +
         COALESCE(n.name_ar, 'N/A')           AS nationality_name_ar,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                               +
         e.sponsorship_status,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      +
         COALESCE(e.employment_status, '')    AS employment_status,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                 +
         s.shift_date::text,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        +
         s.shift_start_time::text,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  +
         s.shift_start_buffer,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      +
         s.shift_end_time::text,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    +
         s.shift_end_buffer,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        +
         s.is_shift_overlapping_next_day,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           +
         s.working_hours,\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           +
         COUNT(*) OVER ()                     AS total_count\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                        +
     FROM special_shift_date_wise s\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 +
     LEFT JOIN hr_employee_master e ON e.id = s.employee_id\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                         +
     LEFT JOIN branches           b ON b.id = e.current_branch_id\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                   +
     LEFT JOIN nationalities      n ON n.id::text = e.nationality_id::text\r                                                                                                                                                                                                                                                                                                                                                                                                                                                          +
     WHERE\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          +
         (p_start_date IS NULL OR s.shift_date >= p_start_date)\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                     +
         AND (p_end_date IS NULL OR s.shift_date <= p_end_date)\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                     +
     ORDER BY s.shift_date DESC\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     +
     LIMIT  p_limit\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 +
     OFFSET p_offset;\r                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               +
 $function$                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           +
 

