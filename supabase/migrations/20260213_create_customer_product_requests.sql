-- Customer Product Requests table
-- Stores product requests from customers submitted by staff via mobile interface
CREATE TABLE IF NOT EXISTS customer_product_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
  target_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed')),
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- RLS policies
ALTER TABLE customer_product_requests ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to customer_product_requests" ON customer_product_requests;

-- Simple permissive policy for all operations (matching app pattern)
CREATE POLICY "Allow all access to customer_product_requests"
  ON customer_product_requests
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (critical - app uses anon role client)
GRANT ALL ON customer_product_requests TO authenticated;
GRANT ALL ON customer_product_requests TO service_role;
GRANT ALL ON customer_product_requests TO anon;

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_customer_product_requests_requester ON customer_product_requests(requester_user_id);
CREATE INDEX IF NOT EXISTS idx_customer_product_requests_target ON customer_product_requests(target_user_id);
CREATE INDEX IF NOT EXISTS idx_customer_product_requests_status ON customer_product_requests(status);
CREATE INDEX IF NOT EXISTS idx_customer_product_requests_branch ON customer_product_requests(branch_id);
