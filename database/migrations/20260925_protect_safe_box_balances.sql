BEGIN;

CREATE OR REPLACE FUNCTION public.protect_main_safe_box_balances()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.record_type = 'main' THEN
	IF TG_OP = 'INSERT' AND (
	  NEW.counts IS NULL
	  OR NOT (NEW.counts ? 'safe_box')
	  OR jsonb_typeof(NEW.counts->'safe_box') <> 'object'
	) THEN
	  RAISE EXCEPTION 'A main denomination record requires persisted Safe Box balances';
	END IF;

    IF TG_OP = 'UPDATE' AND NEW.branch_id IS DISTINCT FROM OLD.branch_id THEN
      RAISE EXCEPTION 'A main denomination record cannot be moved between branches';
    END IF;

    IF TG_OP = 'UPDATE'
       AND OLD.counts ? 'safe_box'
       AND jsonb_typeof(OLD.counts->'safe_box') = 'object'
       AND (
         NEW.counts IS NULL
         OR NOT (NEW.counts ? 'safe_box')
         OR jsonb_typeof(NEW.counts->'safe_box') <> 'object'
       ) THEN
      NEW.counts := jsonb_set(
        coalesce(NEW.counts, '{}'::jsonb),
        '{safe_box}',
        OLD.counts->'safe_box',
        true
      );
      NEW.counts := jsonb_set(
        NEW.counts,
        '{safe_box_balance}',
        coalesce(OLD.counts->'safe_box_balance', '0'::jsonb),
        true
      );
    END IF;

    IF TG_OP = 'UPDATE'
       AND NEW.counts ? 'safe_box'
       AND jsonb_typeof(NEW.counts->'safe_box') = 'object'
       AND NOT (NEW.counts ? 'safe_box_balance') THEN
      NEW.counts := jsonb_set(
        NEW.counts,
        '{safe_box_balance}',
        coalesce(OLD.counts->'safe_box_balance', '0'::jsonb),
        true
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_main_safe_box_balances_trigger ON public.denomination_records;
CREATE TRIGGER protect_main_safe_box_balances_trigger
BEFORE INSERT OR UPDATE ON public.denomination_records
FOR EACH ROW
EXECUTE FUNCTION public.protect_main_safe_box_balances();

COMMIT;
