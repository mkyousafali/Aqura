-- Diagnostic: EMP18 discrepancy on Friday 2026-08-28 between AnalyzeAll (edge function
-- output) and EmployeeAnalysisWindow (live client computation). Read-only.

-- 1) EMP18's regular shift (baseline)
SELECT 'regular' AS kind, v.id AS version_id, v.date_from, v.date_to,
       sl.slot_order, sl.shift_start_time, sl.shift_start_buffer, sl.shift_end_time, sl.shift_end_buffer,
       sl.working_hours, sl.allowed_late_start_minutes, sl.allowed_early_end_minutes
FROM public.hr_regular_shift_versions v
JOIN public.hr_regular_shift_slots sl ON sl.version_id = v.id
WHERE v.employee_id = 'EMP18'
ORDER BY sl.slot_order;

-- 2) EMP18's Friday (weekday=5) special shift version(s)
SELECT 'weekday' AS kind, v.id AS version_id, v.weekday, v.date_from, v.date_to,
       sl.slot_order, sl.shift_start_time, sl.shift_start_buffer, sl.shift_end_time, sl.shift_end_buffer,
       sl.working_hours, sl.allowed_late_start_minutes, sl.allowed_early_end_minutes
FROM public.hr_special_shift_weekday_versions v
JOIN public.hr_special_shift_weekday_slots sl ON sl.version_id = v.id
WHERE v.employee_id = 'EMP18' AND v.weekday = 5
ORDER BY v.date_from, sl.slot_order;

-- 3) Any date-wise override for EMP18 on 2026-08-28 (would take priority over weekday)
SELECT 'date_wise' AS kind, v.id AS version_id, v.date_from, v.date_to,
       sl.slot_order, sl.shift_start_time, sl.shift_start_buffer, sl.shift_end_time, sl.shift_end_buffer,
       sl.working_hours, sl.allowed_late_start_minutes, sl.allowed_early_end_minutes
FROM public.hr_special_shift_date_wise_versions v
JOIN public.hr_special_shift_date_wise_slots sl ON sl.version_id = v.id
WHERE v.employee_id = 'EMP18' AND v.date_from <= '2026-08-28' AND v.date_to >= '2026-08-28';

-- 4) Raw fingerprint punches for EMP18 around 2026-08-28
SELECT center_id, punch_date, punch_time, punch_type, created_at
FROM public.processed_fingerprint_transactions
WHERE center_id = 'EMP18' AND punch_date BETWEEN '2026-08-27' AND '2026-08-29'
ORDER BY punch_date, punch_time;

-- 5) What the edge function actually stored for 2026-08-28
SELECT employee_id, shift_date, status, worked_minutes, late_minutes, under_minutes,
       shift_start_time, shift_end_time, check_in_time, check_out_time, analyzed_at
FROM public.hr_analysed_attendance_data
WHERE employee_id = 'EMP18' AND shift_date = '2026-08-28';

-- 6) Day-off override check for that Friday
SELECT * FROM public.day_off_weekday WHERE employee_id = 'EMP18';
