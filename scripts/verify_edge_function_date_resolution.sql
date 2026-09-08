-- Step 3 verification: confirm the LIVE analyze-attendance edge function actually
-- picked the historically-correct regular-shift version for employees who have
-- more than one hr_regular_shift_versions row (i.e. their standing shift changed).
-- Read-only.

WITH multi_version_employees AS (
    SELECT employee_id, count(*) AS version_count
    FROM public.hr_regular_shift_versions
    GROUP BY employee_id
    HAVING count(*) > 1
),
versions AS (
    SELECT v.employee_id, v.id AS version_id, v.date_from, v.date_to,
           sl.shift_start_time, sl.shift_end_time
    FROM public.hr_regular_shift_versions v
    JOIN public.hr_regular_shift_slots sl ON sl.version_id = v.id AND sl.slot_order = 1
    WHERE v.employee_id IN (SELECT employee_id FROM multi_version_employees)
)
SELECT v.employee_id, v.version_id, v.date_from AS version_date_from, v.date_to AS version_date_to,
       v.shift_start_time AS version_start, v.shift_end_time AS version_end,
       a.shift_date, a.shift_start_time AS analysed_start, a.shift_end_time AS analysed_end,
       CASE WHEN a.shift_start_time = v.shift_start_time AND a.shift_end_time = v.shift_end_time
            THEN 'MATCH' ELSE 'MISMATCH' END AS result
FROM versions v
JOIN public.hr_analysed_attendance_data a
  ON a.employee_id = v.employee_id
  AND a.shift_date >= v.date_from
  AND (v.date_to IS NULL OR a.shift_date <= v.date_to)
ORDER BY v.employee_id, a.shift_date;

-- Summary counts
WITH multi_version_employees AS (
    SELECT employee_id, count(*) AS version_count
    FROM public.hr_regular_shift_versions
    GROUP BY employee_id
    HAVING count(*) > 1
),
versions AS (
    SELECT v.employee_id, v.id AS version_id, v.date_from, v.date_to,
           sl.shift_start_time, sl.shift_end_time
    FROM public.hr_regular_shift_versions v
    JOIN public.hr_regular_shift_slots sl ON sl.version_id = v.id AND sl.slot_order = 1
    WHERE v.employee_id IN (SELECT employee_id FROM multi_version_employees)
)
SELECT
  count(*) FILTER (WHERE a.shift_start_time = v.shift_start_time AND a.shift_end_time = v.shift_end_time) AS matches,
  count(*) FILTER (WHERE a.shift_start_time IS DISTINCT FROM v.shift_start_time OR a.shift_end_time IS DISTINCT FROM v.shift_end_time) AS mismatches,
  count(*) AS total
FROM versions v
JOIN public.hr_analysed_attendance_data a
  ON a.employee_id = v.employee_id
  AND a.shift_date >= v.date_from
  AND (v.date_to IS NULL OR a.shift_date <= v.date_to);

-- How many employees have multiple regular-shift versions at all (scope of the bug)?
SELECT count(*) AS employees_with_multiple_regular_versions
FROM (
    SELECT employee_id FROM public.hr_regular_shift_versions GROUP BY employee_id HAVING count(*) > 1
) x;
