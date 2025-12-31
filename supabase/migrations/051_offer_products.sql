-- Offer Products Table Schema
CREATE TABLE IF NOT EXISTS offer_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id INTEGER NOT NULL,
  product_id VARCHAR NOT NULL,
  offer_qty INTEGER NOT NULL DEFAULT 1,
  offer_percentage NUMERIC,
  offer_price NUMERIC,
  max_uses INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  is_part_of_variation_group BOOLEAN NOT NULL DEFAULT false,
  variation_group_id UUID,
  variation_parent_barcode TEXT,
  added_by UUID,
  added_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
