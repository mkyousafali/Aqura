BEGIN;

-- Redemption status remains 'confirmed': changing it would incorrectly restore
-- points when loyalty balances are recalculated. Coupon use is a separate record.
CREATE TABLE IF NOT EXISTS public.loyalty_coupon_uses (
  redemption_id uuid PRIMARY KEY REFERENCES public.loyalty_redemptions(id),
  operation_id uuid NOT NULL REFERENCES public.box_operations(id),
  cashier_id uuid NOT NULL,
  branch_id integer NOT NULL,
  amount numeric(14,2) NOT NULL CHECK (amount > 0),
  used_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS loyalty_coupon_uses_operation_idx ON public.loyalty_coupon_uses(operation_id);
ALTER TABLE public.loyalty_coupon_uses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.loyalty_coupon_uses FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.loyalty_coupon_uses TO service_role;

-- Coupons on counters already closed by older clients must not become reusable.
INSERT INTO public.loyalty_coupon_uses (redemption_id, operation_id, cashier_id, branch_id, amount, used_at)
SELECT DISTINCT ON (r.id) r.id, b.id, b.user_id, b.branch_id, r.coupon_value,
  COALESCE(b.end_time, b.updated_at, now())
FROM public.box_operations b
CROSS JOIN LATERAL jsonb_array_elements(
  CASE WHEN jsonb_typeof(b.closing_details->'loyalty_vouchers') = 'array'
       THEN b.closing_details->'loyalty_vouchers' ELSE '[]'::jsonb END) item
JOIN public.loyalty_redemptions r ON r.coupon_code = upper(trim(item->>'serial'))
WHERE b.status IN ('pending_close', 'completed') AND r.status = 'confirmed' AND r.coupon_value > 0
ORDER BY r.id, COALESCE(b.end_time, b.updated_at), b.id
ON CONFLICT (redemption_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.consume_closing_loyalty_coupons() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  items jsonb := COALESCE(NEW.closing_details->'loyalty_vouchers', '[]'::jsonb);
  item jsonb;
  coupon public.loyalty_redemptions%rowtype;
  previous_operation uuid;
  amount numeric;
  coupon_total numeric := 0;
BEGIN
  IF jsonb_typeof(items) <> 'array' THEN RAISE EXCEPTION 'Invalid loyalty coupon list'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.loyalty_coupon_uses u
    JOIN public.loyalty_redemptions r ON r.id = u.redemption_id
    WHERE u.operation_id = NEW.id AND NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(items) x WHERE upper(trim(x->>'serial')) = r.coupon_code
    )
  ) THEN RAISE EXCEPTION 'Used loyalty coupons cannot be removed from this closing'; END IF;

  -- Draft/autosave does not consume coupons.
  IF NEW.status NOT IN ('pending_close', 'completed') THEN RETURN NEW; END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(items)) <>
     (SELECT count(DISTINCT upper(trim(x->>'serial'))) FROM jsonb_array_elements(items) x)
  THEN RAISE EXCEPTION 'Duplicate loyalty coupon in this closing'; END IF;

  -- Consistent lock order prevents concurrent counters from spending one coupon.
  FOR item IN SELECT value FROM jsonb_array_elements(items) ORDER BY upper(trim(value->>'serial')) LOOP
    SELECT * INTO coupon FROM public.loyalty_redemptions
      WHERE coupon_code = upper(trim(item->>'serial')) FOR UPDATE;
    IF NOT FOUND OR coupon.status <> 'confirmed' THEN
      RAISE EXCEPTION 'Loyalty coupon % is not confirmed', item->>'serial';
    END IF;
    amount := (item->>'amount')::numeric;
    IF amount IS NULL OR amount <= 0 OR amount <> coupon.coupon_value THEN
      RAISE EXCEPTION 'Loyalty coupon % amount does not match', coupon.coupon_code;
    END IF;
    SELECT operation_id INTO previous_operation FROM public.loyalty_coupon_uses WHERE redemption_id = coupon.id;
    IF FOUND AND previous_operation <> NEW.id THEN
      RAISE EXCEPTION 'Loyalty coupon % has already been used', coupon.coupon_code;
    END IF;
    INSERT INTO public.loyalty_coupon_uses (redemption_id, operation_id, cashier_id, branch_id, amount)
      VALUES (coupon.id, NEW.id, NEW.user_id, NEW.branch_id, amount)
      ON CONFLICT (redemption_id) DO NOTHING;
    coupon_total := coupon_total + amount;
  END LOOP;
  IF round(COALESCE((NEW.closing_details->>'loyalty_vouchers_total')::numeric, 0), 2) <> coupon_total THEN
    RAISE EXCEPTION 'Loyalty coupon total does not match';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.consume_closing_loyalty_coupons() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS consume_closing_loyalty_coupons ON public.box_operations;
CREATE TRIGGER consume_closing_loyalty_coupons
AFTER INSERT OR UPDATE OF status, closing_details ON public.box_operations
FOR EACH ROW EXECUTE FUNCTION public.consume_closing_loyalty_coupons();

NOTIFY pgrst, 'reload schema';
COMMIT;
