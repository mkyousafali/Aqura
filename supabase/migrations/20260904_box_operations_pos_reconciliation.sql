-- Add a JSONB column to hold POS reconciliation data for a box operation.

ALTER TABLE public.box_operations
    ADD COLUMN IF NOT EXISTS pos_reconciliation jsonb;

COMMENT ON COLUMN public.box_operations.pos_reconciliation IS 'POS reconciliation data for this box operation';
