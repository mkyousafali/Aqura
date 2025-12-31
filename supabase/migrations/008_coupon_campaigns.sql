-- Coupon Campaigns Table Schema
CREATE TABLE IF NOT EXISTS coupon_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_name VARCHAR,
  campaign_code VARCHAR NOT NULL,
  description TEXT,
  validity_start_date TIMESTAMP WITH TIME ZONE,
  validity_end_date TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN DEFAULT true,
  terms_conditions_en TEXT,
  terms_conditions_ar TEXT,
  created_by UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  deleted_at TIMESTAMP WITH TIME ZONE,
  name_en VARCHAR NOT NULL,
  name_ar VARCHAR NOT NULL,
  start_date TIMESTAMP WITH TIME ZONE NOT NULL,
  end_date TIMESTAMP WITH TIME ZONE NOT NULL,
  max_claims_per_customer INTEGER DEFAULT 1
);
