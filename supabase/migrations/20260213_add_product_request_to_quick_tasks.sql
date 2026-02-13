-- Add product_request_id and product_request_type columns to quick_tasks
-- for linking quick tasks to product requests (ST/BT/PO)

ALTER TABLE quick_tasks ADD COLUMN IF NOT EXISTS product_request_id UUID;
ALTER TABLE quick_tasks ADD COLUMN IF NOT EXISTS product_request_type VARCHAR(5);

COMMENT ON COLUMN quick_tasks.product_request_id IS 'Reference to the product request that triggered this quick task';
COMMENT ON COLUMN quick_tasks.product_request_type IS 'Type of product request: PO, ST, or BT';

-- Indexes for quick lookup
CREATE INDEX IF NOT EXISTS idx_quick_tasks_product_request_id ON quick_tasks(product_request_id);
CREATE INDEX IF NOT EXISTS idx_quick_tasks_product_request_type ON quick_tasks(product_request_type);
