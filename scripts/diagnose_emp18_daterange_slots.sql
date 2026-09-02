-- Diagnostic: EMP18's date-wise "Special Range" (10-08-2026 -> 31-08-2026) shown
-- with blank Start/End/Working Hours/Buffer in the Shifts window. Check whether
-- the underlying versions actually have slot rows. Read-only.

SELECT v.id AS version_id, v.date_from, v.date_to, v.created_at,
       sl.id AS slot_id, sl.shift_start_time, sl.shift_end_time, sl.working_hours,
       sl.shift_start_buffer, sl.shift_end_buffer
FROM public.hr_special_shift_date_wise_versions v
LEFT JOIN public.hr_special_shift_date_wise_slots sl ON sl.version_id = v.id
WHERE v.employee_id = 'EMP18'
  AND v.date_from BETWEEN '2026-08-10' AND '2026-08-31'
ORDER BY v.date_from;

-- Count how many of those versions have zero slot rows (orphaned)
SELECT count(*) AS versions_in_range,
       count(*) FILTER (WHERE sl.id IS NULL) AS versions_missing_slots
FROM public.hr_special_shift_date_wise_versions v
LEFT JOIN public.hr_special_shift_date_wise_slots sl ON sl.version_id = v.id
WHERE v.employee_id = 'EMP18'
  AND v.date_from BETWEEN '2026-08-10' AND '2026-08-31';
