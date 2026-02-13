-- Product Request - Branch Transfer (BT)
-- Stores requests to transfer products from one branch to another

CREATE TABLE IF NOT EXISTS product_request_bt (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  from_branch_id INTEGER NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
  to_branch_id INTEGER NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
  target_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_product_request_bt_requester ON product_request_bt(requester_user_id);
CREATE INDEX IF NOT EXISTS idx_product_request_bt_target ON product_request_bt(target_user_id);
CREATE INDEX IF NOT EXISTS idx_product_request_bt_from_branch ON product_request_bt(from_branch_id);
CREATE INDEX IF NOT EXISTS idx_product_request_bt_to_branch ON product_request_bt(to_branch_id);
CREATE INDEX IF NOT EXISTS idx_product_request_bt_status ON product_request_bt(status);
CREATE INDEX IF NOT EXISTS idx_product_request_bt_created ON product_request_bt(created_at);

-- Auto-update trigger for updated_at
CREATE OR REPLACE FUNCTION update_product_request_bt_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER product_request_bt_timestamp_update
BEFORE UPDATE ON product_request_bt
FOR EACH ROW
EXECUTE FUNCTION update_product_request_bt_timestamp();
