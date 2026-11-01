-- Stable ERP-source identity makes concurrent PC retries idempotent.
-- Leaves existing loyalty records intact. Apply before using SQLite cloud sync.
ALTER TABLE public.loyalty_customer_bills ADD COLUMN IF NOT EXISTS source_identity text;
CREATE UNIQUE INDEX IF NOT EXISTS loyalty_customer_bills_source_identity_unique
  ON public.loyalty_customer_bills(source_identity)
  WHERE source_identity IS NOT NULL;
