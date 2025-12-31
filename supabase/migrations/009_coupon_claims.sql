-- Coupon Claims Table Schema
CREATE TABLE IF NOT EXISTS coupon_claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL,
  customer_mobile VARCHAR NOT NULL,
  product_id UUID,
  branch_id BIGINT,
  claimed_by_user UUID,
  claimed_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  print_count INTEGER DEFAULT 1,
  barcode_scanned BOOLEAN DEFAULT false,
  validity_date DATE NOT NULL,
  status VARCHAR DEFAULT 'claimed',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  max_claims_per_customer INTEGER DEFAULT 1
);
