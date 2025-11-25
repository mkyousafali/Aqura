-- Migration 1: Add Variation Columns to flyer_products
-- This migration adds all necessary columns to support product variation grouping

-- Add variation-related columns to flyer_products table
ALTER TABLE flyer_products
  ADD COLUMN IF NOT EXISTS is_variation BOOLEAN DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS parent_product_barcode TEXT,
  ADD COLUMN IF NOT EXISTS variation_group_name_en TEXT,
  ADD COLUMN IF NOT EXISTS variation_group_name_ar TEXT,
  ADD COLUMN IF NOT EXISTS variation_order INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS variation_image_override TEXT,
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS modified_by UUID REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS modified_at TIMESTAMPTZ;

-- Add foreign key constraint for parent product relationship
ALTER TABLE flyer_products
  ADD CONSTRAINT fk_parent_product_barcode
  FOREIGN KEY (parent_product_barcode)
  REFERENCES flyer_products(barcode)
  ON DELETE SET NULL;

-- Create indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_flyer_products_parent_barcode 
  ON flyer_products(parent_product_barcode) 
  WHERE parent_product_barcode IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_flyer_products_is_variation 
  ON flyer_products(is_variation) 
  WHERE is_variation = true;

CREATE INDEX IF NOT EXISTS idx_flyer_products_variation_composite 
  ON flyer_products(is_variation, parent_product_barcode);

CREATE INDEX IF NOT EXISTS idx_flyer_products_barcode 
  ON flyer_products(barcode);

-- Add comment documentation
COMMENT ON COLUMN flyer_products.is_variation IS 'Flag indicating if this product is part of a variation group';
COMMENT ON COLUMN flyer_products.parent_product_barcode IS 'Barcode of the parent product in the variation group';
COMMENT ON COLUMN flyer_products.variation_group_name_en IS 'English name for the variation group';
COMMENT ON COLUMN flyer_products.variation_group_name_ar IS 'Arabic name for the variation group';
COMMENT ON COLUMN flyer_products.variation_order IS 'Display order within the variation group';
COMMENT ON COLUMN flyer_products.variation_image_override IS 'Optional override for group display image (URL or barcode reference)';
COMMENT ON COLUMN flyer_products.created_by IS 'User who created this variation group';
COMMENT ON COLUMN flyer_products.modified_by IS 'User who last modified this variation group';
COMMENT ON COLUMN flyer_products.modified_at IS 'Timestamp of last modification to variation settings';
