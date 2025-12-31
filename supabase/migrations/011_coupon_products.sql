-- Coupon Products Table Schema
CREATE TABLE IF NOT EXISTS coupon_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL,
  product_name_en VARCHAR NOT NULL,
  product_name_ar VARCHAR NOT NULL,
  product_image_url TEXT,
  original_price NUMERIC NOT NULL,
  offer_price NUMERIC NOT NULL,
  special_barcode VARCHAR NOT NULL,
  stock_limit INTEGER NOT NULL DEFAULT 0,
  stock_remaining INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_by UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  deleted_at TIMESTAMP WITH TIME ZONE,
  flyer_product_id VARCHAR
);
