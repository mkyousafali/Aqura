-- Replace the free-text reconciliation number on bank_reconciliations with structured
-- fields taken directly off the physical card-terminal (mada) reconciliation slip.

ALTER TABLE public.bank_reconciliations
    ADD COLUMN IF NOT EXISTS recon_date date,
    ADD COLUMN IF NOT EXISTS recon_time time,
    ADD COLUMN IF NOT EXISTS terminal_id text,
    ADD COLUMN IF NOT EXISTS statement_match_number text;

COMMENT ON COLUMN public.bank_reconciliations.recon_date IS 'Date printed on the card terminal reconciliation slip';
COMMENT ON COLUMN public.bank_reconciliations.recon_time IS 'Time printed on the card terminal reconciliation slip';
COMMENT ON COLUMN public.bank_reconciliations.terminal_id IS 'Terminal ID printed on the card terminal reconciliation slip';
COMMENT ON COLUMN public.bank_reconciliations.statement_match_number IS 'Statement match number printed on the card terminal reconciliation slip';
