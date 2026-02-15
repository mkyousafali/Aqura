-- Add expiry_hidden boolean column to erp_synced_products
-- When true, the product is excluded from expiry reports (Quick Report & Near Expiry)

ALTER TABLE erp_synced_products
ADD COLUMN IF NOT EXISTS expiry_hidden boolean DEFAULT false;

-- Index for faster filtering
CREATE INDEX IF NOT EXISTS idx_erp_synced_products_expiry_hidden
ON erp_synced_products (expiry_hidden)
WHERE expiry_hidden = true;
