BEGIN;

ALTER TABLE public.aqura_change_requests
  ADD COLUMN IF NOT EXISTS request_date date,
  ADD COLUMN IF NOT EXISTS daily_serial bigint,
  ADD COLUMN IF NOT EXISTS request_number text;

-- Existing requests receive stable numbers in their Riyadh calendar day.
WITH numbered AS (
  SELECT id,
    (requested_at AT TIME ZONE 'Asia/Riyadh')::date AS local_date,
    row_number() OVER (
      PARTITION BY branch_id, (requested_at AT TIME ZONE 'Asia/Riyadh')::date
      ORDER BY requested_at, id
    ) AS serial
  FROM public.aqura_change_requests
  WHERE request_number IS NULL
)
UPDATE public.aqura_change_requests AS request SET
  request_date = numbered.local_date,
  daily_serial = numbered.serial,
  request_number = to_char(numbered.local_date, 'DDMMYYYY') || request.branch_id::text || numbered.serial::text
FROM numbered
WHERE request.id = numbered.id;

CREATE UNIQUE INDEX IF NOT EXISTS aqura_change_requests_request_number_key
  ON public.aqura_change_requests (request_number);
CREATE UNIQUE INDEX IF NOT EXISTS aqura_change_requests_daily_serial_key
  ON public.aqura_change_requests (request_date, branch_id, daily_serial);

CREATE OR REPLACE FUNCTION public.aqura_assign_change_request_number()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_serial bigint;
  v_number text;
BEGIN
  NEW.request_date := (NEW.requested_at AT TIME ZONE 'Asia/Riyadh')::date;
  -- One lock per calendar day also protects against ambiguous digit combinations
  -- from different branch IDs when their serials become long.
  PERFORM pg_advisory_xact_lock(734205, (NEW.request_date - DATE '2000-01-01')::integer);
  SELECT coalesce(max(daily_serial), 0) + 1 INTO v_serial
  FROM public.aqura_change_requests
  WHERE request_date = NEW.request_date AND branch_id = NEW.branch_id;
  LOOP
    v_number := to_char(NEW.request_date, 'DDMMYYYY') || NEW.branch_id::text || v_serial::text;
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.aqura_change_requests WHERE request_number = v_number
    );
    v_serial := v_serial + 1;
  END LOOP;
  NEW.daily_serial := v_serial;
  NEW.request_number := v_number;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS aqura_assign_change_request_number_trigger ON public.aqura_change_requests;
CREATE TRIGGER aqura_assign_change_request_number_trigger
  BEFORE INSERT ON public.aqura_change_requests
  FOR EACH ROW EXECUTE FUNCTION public.aqura_assign_change_request_number();

ALTER TABLE public.aqura_change_requests
  ALTER COLUMN request_date SET NOT NULL,
  ALTER COLUMN daily_serial SET NOT NULL,
  ALTER COLUMN request_number SET NOT NULL;

COMMIT;
