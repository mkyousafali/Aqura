-- Coupon Eligible Customers Table Schema
CREATE TABLE IF NOT EXISTS coupon_eligible_customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL,
  mobile_number VARCHAR NOT NULL,
  customer_name VARCHAR,
  import_batch_id UUID,
  imported_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  imported_by UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
