-- Remove 'Run Away', 'Terminated', and 'Job (No Finger)' from the allowed
-- hr_employee_master.employment_status values. Confirmed via query before
-- writing this migration that zero employees currently hold any of these
-- three values (the one employee who was 'Terminated', EMP38, was moved to
-- 'Resigned' first, with a note preserved in employment_status_reason since
-- there is no status-change history table).

-- Safety check: abort if any employee still holds one of the values being removed.
DO $$
DECLARE
  remaining_count integer;
BEGIN
  SELECT count(*) INTO remaining_count
  FROM public.hr_employee_master
  WHERE employment_status IN ('Run Away', 'Terminated', 'Job (No Finger)');

  IF remaining_count > 0 THEN
    RAISE EXCEPTION 'Cannot remove deprecated employment statuses: % employee(s) still use one of them', remaining_count;
  END IF;
END $$;

ALTER TABLE public.hr_employee_master
  DROP CONSTRAINT employment_status_values;

ALTER TABLE public.hr_employee_master
  ADD CONSTRAINT employment_status_values
  CHECK ((employment_status = ANY (ARRAY[
    'Resigned'::text,
    'Job (With Finger)'::text,
    'Vacation'::text,
    'Remote Job'::text
  ])));
