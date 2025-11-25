-- Migration 2: Add Variation Tracking to offer_products
-- This migration adds columns to track which variations are included in offers

-- Add variation tracking columns to offer_products table
ALTER TABLE offer_products
  ADD COLUMN IF NOT EXISTS is_part_of_variation_group BOOLEAN DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS variation_group_id UUID,
  ADD COLUMN IF NOT EXISTS variation_parent_barcode TEXT,
  ADD COLUMN IF NOT EXISTS added_by UUID REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS added_at TIMESTAMPTZ DEFAULT NOW();

-- Create indexes for fast group queries
CREATE INDEX IF NOT EXISTS idx_offer_products_variation_group_id 
  ON offer_products(variation_group_id) 
  WHERE variation_group_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_offer_products_variation_parent 
  ON offer_products(variation_parent_barcode) 
  WHERE variation_parent_barcode IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_offer_products_is_variation 
  ON offer_products(is_part_of_variation_group) 
  WHERE is_part_of_variation_group = true;

-- Add comment documentation
COMMENT ON COLUMN offer_products.is_part_of_variation_group IS 'Flag indicating if this product belongs to a variation group within the offer';
COMMENT ON COLUMN offer_products.variation_group_id IS 'UUID linking all variations in the same group within an offer';
COMMENT ON COLUMN offer_products.variation_parent_barcode IS 'Quick reference to the parent product barcode';
COMMENT ON COLUMN offer_products.added_by IS 'User who added this variation to the offer';
COMMENT ON COLUMN offer_products.added_at IS 'Timestamp when this variation was added to the offer';
