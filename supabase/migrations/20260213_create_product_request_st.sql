-- Product Request - In-Branch / Stock Transfer (ST)
-- Stores in-branch product requests

CREATE TABLE IF NOT EXISTS product_request_st (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  branch_id INTEGER NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
  target_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_product_request_st_requester ON product_request_st(requester_user_id);
CREATE INDEX IF NOT EXISTS idx_product_request_st_target ON product_request_st(target_user_id);
CREATE INDEX IF NOT EXISTS idx_product_request_st_branch ON product_request_st(branch_id);
CREATE INDEX IF NOT EXISTS idx_product_request_st_status ON product_request_st(status);
CREATE INDEX IF NOT EXISTS idx_product_request_st_created ON product_request_st(created_at);

-- Auto-update trigger for updated_at
CREATE OR REPLACE FUNCTION update_product_request_st_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER product_request_st_timestamp_update
BEFORE UPDATE ON product_request_st
FOR EACH ROW
EXECUTE FUNCTION update_product_request_st_timestamp();
