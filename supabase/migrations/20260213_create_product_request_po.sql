-- Product Request - Purchase Order (PO)
-- Stores purchase order requests sent to purchasing managers

CREATE TABLE IF NOT EXISTS product_request_po (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  from_branch_id INTEGER NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
  target_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_product_request_po_requester ON product_request_po(requester_user_id);
CREATE INDEX IF NOT EXISTS idx_product_request_po_target ON product_request_po(target_user_id);
CREATE INDEX IF NOT EXISTS idx_product_request_po_branch ON product_request_po(from_branch_id);
CREATE INDEX IF NOT EXISTS idx_product_request_po_status ON product_request_po(status);
CREATE INDEX IF NOT EXISTS idx_product_request_po_created ON product_request_po(created_at);

-- Auto-update trigger for updated_at
CREATE OR REPLACE FUNCTION update_product_request_po_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER product_request_po_timestamp_update
BEFORE UPDATE ON product_request_po
FOR EACH ROW
EXECUTE FUNCTION update_product_request_po_timestamp();
