-- Add in_process JSONB column to erp_synced_products
ALTER TABLE public.erp_synced_products
ADD COLUMN IF NOT EXISTS in_process jsonb NULL DEFAULT '[]'::jsonb;

-- Index for GIN queries on in_process
CREATE INDEX IF NOT EXISTS idx_erp_synced_products_in_process
ON public.erp_synced_products USING gin (in_process);
