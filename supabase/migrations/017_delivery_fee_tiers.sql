-- Delivery Fee Tiers Table Schema
CREATE TABLE IF NOT EXISTS delivery_fee_tiers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  min_order_amount NUMERIC NOT NULL,
  max_order_amount NUMERIC,
  delivery_fee NUMERIC NOT NULL,
  tier_order INTEGER NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  description_en TEXT,
  description_ar TEXT,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  branch_id BIGINT
);
