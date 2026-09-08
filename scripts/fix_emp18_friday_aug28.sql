-- Remove the Friday (2026-08-28) date-wise overrides for EMP18 so the Friday
-- weekday special shift (13:00-21:00, effective from 2026-08-25) can apply instead.
BEGIN;

-- Clean single-day Friday entry: delete outright (cascades to its slot row).
DELETE FROM public.hr_special_shift_date_wise_versions WHERE id = 2698;

-- Range entry (28-08 -> 01-09): shrink to exclude the Friday, keep 29/30/01 coverage.
UPDATE public.hr_special_shift_date_wise_versions
SET date_from = '2026-08-29'
WHERE id = 3374;

-- Verify: no date-wise version should cover 2026-08-28 for EMP18 anymore.
SELECT v.id, v.date_from, v.date_to, sl.shift_start_time, sl.shift_end_time
FROM public.hr_special_shift_date_wise_versions v
JOIN public.hr_special_shift_date_wise_slots sl ON sl.version_id = v.id
WHERE v.employee_id = 'EMP18' AND v.date_from <= '2026-08-28' AND v.date_to >= '2026-08-28';

COMMIT;
