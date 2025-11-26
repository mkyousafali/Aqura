-- Add flyer_product_id reference to coupon_products table
-- This allows tracking which flyer product each coupon product came from
-- even if the barcode is changed

ALTER TABLE coupon_products 
ADD COLUMN IF NOT EXISTS flyer_product_id UUID REFERENCES flyer_products(id) ON DELETE SET NULL;

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_coupon_products_flyer_product 
ON coupon_products(flyer_product_id);

-- Add comment
COMMENT ON COLUMN coupon_products.flyer_product_id IS 'Reference to the source flyer product, allows tracking even if barcode changes';
