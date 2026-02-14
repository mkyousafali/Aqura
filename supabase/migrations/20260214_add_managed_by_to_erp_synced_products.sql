-- Add managed_by JSONB column to erp_synced_products
-- Stores array of { employee_id, branch_id, name_en, name_ar, claimed_at }
-- Same product can be claimed by multiple employees from same or different branches

ALTER TABLE public.erp_synced_products
ADD COLUMN IF NOT EXISTS managed_by JSONB DEFAULT '[]'::jsonb;

-- GIN index for fast JSONB lookups
CREATE INDEX IF NOT EXISTS idx_erp_synced_products_managed_by
ON public.erp_synced_products USING gin (managed_by);
