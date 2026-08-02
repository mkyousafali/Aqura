-- RPC functions to fetch shift versions+slots joined, accepting employee_ids only.
-- This avoids the URL-too-long issue from passing thousands of version IDs in .in() queries.

-- Regular shifts: returns 1 row per slot, with version info
CREATE OR REPLACE FUNCTION public.get_hr_regular_shifts(p_employee_ids text[])
RETURNS TABLE(
    employee_id text, version_id bigint, date_from date, date_to date,
    slot_order integer, shift_start_time time, shift_start_buffer numeric,
    shift_end_time time, shift_end_buffer numeric,
    is_shift_overlapping_next_day boolean, working_hours numeric
)
LANGUAGE sql SECURITY DEFINER SET search_path TO 'public'
AS $function$
    SELECT v.employee_id, v.id AS version_id, v.date_from, v.date_to,
           sl.slot_order, sl.shift_start_time, sl.shift_start_buffer,
           sl.shift_end_time, sl.shift_end_buffer,
           sl.is_shift_overlapping_next_day, sl.working_hours
    FROM hr_regular_shift_versions v
    JOIN hr_regular_shift_slots sl ON sl.version_id = v.id
    WHERE v.employee_id = ANY(p_employee_ids)
    ORDER BY v.employee_id, sl.slot_order;
$function$;

-- Weekday shifts: returns 1 row per slot, with version info including weekday
CREATE OR REPLACE FUNCTION public.get_hr_weekday_shifts(p_employee_ids text[])
RETURNS TABLE(
    employee_id text, version_id bigint, weekday integer, date_from date, date_to date,
    slot_order integer, shift_start_time time, shift_start_buffer numeric,
    shift_end_time time, shift_end_buffer numeric,
    is_shift_overlapping_next_day boolean, working_hours numeric
)
LANGUAGE sql SECURITY DEFINER SET search_path TO 'public'
AS $function$
    SELECT v.employee_id, v.id AS version_id, v.weekday, v.date_from, v.date_to,
           sl.slot_order, sl.shift_start_time, sl.shift_start_buffer,
           sl.shift_end_time, sl.shift_end_buffer,
           sl.is_shift_overlapping_next_day, sl.working_hours
    FROM hr_special_shift_weekday_versions v
    JOIN hr_special_shift_weekday_slots sl ON sl.version_id = v.id
    WHERE v.employee_id = ANY(p_employee_ids)
    ORDER BY v.employee_id, v.weekday, sl.slot_order;
$function$;

-- Date-wise shifts: returns 1 row per slot, with version info including dates
CREATE OR REPLACE FUNCTION public.get_hr_date_wise_shifts(p_employee_ids text[])
RETURNS TABLE(
    employee_id text, version_id bigint, date_from date, date_to date,
    slot_order integer, shift_start_time time, shift_start_buffer numeric,
    shift_end_time time, shift_end_buffer numeric,
    is_shift_overlapping_next_day boolean, working_hours numeric
)
LANGUAGE sql SECURITY DEFINER SET search_path TO 'public'
AS $function$
    SELECT v.employee_id, v.id AS version_id, v.date_from, v.date_to,
           sl.slot_order, sl.shift_start_time, sl.shift_start_buffer,
           sl.shift_end_time, sl.shift_end_buffer,
           sl.is_shift_overlapping_next_day, sl.working_hours
    FROM hr_special_shift_date_wise_versions v
    JOIN hr_special_shift_date_wise_slots sl ON sl.version_id = v.id
    WHERE v.employee_id = ANY(p_employee_ids)
    ORDER BY v.employee_id, v.date_from, sl.slot_order;
$function$;
