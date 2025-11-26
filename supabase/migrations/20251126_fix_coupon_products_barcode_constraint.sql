-- ================================================
-- FIX COUPON PRODUCTS BARCODE CONSTRAINT
-- Created: November 26, 2025
-- Description: Allow same barcode across different campaigns
--              but keep unique within each campaign
-- ================================================

-- Step 1: Drop the existing unique constraint on special_barcode
ALTER TABLE coupon_products
DROP CONSTRAINT IF EXISTS coupon_products_special_barcode_key;

-- Step 2: Create a compound unique constraint on campaign_id + special_barcode
-- This allows the same barcode in different campaigns, but not duplicates within same campaign
ALTER TABLE coupon_products
ADD CONSTRAINT coupon_products_campaign_barcode_unique 
UNIQUE (campaign_id, special_barcode);

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'Coupon products barcode constraint updated successfully!';
  RAISE NOTICE 'Same barcode can now be used across different campaigns';
  RAISE NOTICE 'But remains unique within each campaign';
END $$;
