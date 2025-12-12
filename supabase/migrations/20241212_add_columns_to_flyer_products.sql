-- Migration: Add missing columns to flyer_products table
-- Purpose: Make flyer_products compatible with customer app requirements
-- Date: 2024-12-12
-- WARNING: This is a major schema change. Review carefully before applying.

-- ============================================
-- STEP 1: Add new columns to flyer_products
-- ============================================

-- Add product_serial (unique identifier like products table)
ALTER TABLE flyer_products 
ADD COLUMN IF NOT EXISTS product_serial text;

-- Add pricing fields
ALTER TABLE flyer_products 
ADD COLUMN IF NOT EXISTS sale_price numeric DEFAULT 0 NOT NULL,
ADD COLUMN IF NOT EXISTS cost numeric DEFAULT 0 NOT NULL,
ADD COLUMN IF NOT EXISTS profit numeric DEFAULT 0 NOT NULL,
ADD COLUMN IF NOT EXISTS profit_percentage numeric DEFAULT 0 NOT NULL;

-- Add inventory/stock management fields
ALTER TABLE flyer_products 
ADD COLUMN IF NOT EXISTS current_stock integer DEFAULT 0 NOT NULL,
ADD COLUMN IF NOT EXISTS minim_qty integer DEFAULT 0 NOT NULL,
ADD COLUMN IF NOT EXISTS minimum_qty_alert integer DEFAULT 0 NOT NULL,
ADD COLUMN IF NOT EXISTS maximum_qty integer DEFAULT 0 NOT NULL;

-- Add category foreign key relationship
ALTER TABLE flyer_products 
ADD COLUMN IF NOT EXISTS category_id uuid;

-- Add tax management fields
ALTER TABLE flyer_products 
ADD COLUMN IF NOT EXISTS tax_category_id uuid,
ADD COLUMN IF NOT EXISTS tax_category_name_en text DEFAULT '' NOT NULL,
ADD COLUMN IF NOT EXISTS tax_category_name_ar text DEFAULT '' NOT NULL,
ADD COLUMN IF NOT EXISTS tax_percentage numeric DEFAULT 0 NOT NULL;

-- Add unit foreign key relationship
ALTER TABLE flyer_products 
ADD COLUMN IF NOT EXISTS unit_id uuid;

-- Add unit quantity (different from unit_name which is text)
ALTER TABLE flyer_products 
ADD COLUMN IF NOT EXISTS unit_qty numeric DEFAULT 1 NOT NULL;

-- Add unit names in both languages (if not exists - flyer_products has unit_name)
ALTER TABLE flyer_products 
ADD COLUMN IF NOT EXISTS unit_name_en text,
ADD COLUMN IF NOT EXISTS unit_name_ar text;

-- Add category names in both languages (flyer_products uses parent_category, sub_category)
ALTER TABLE flyer_products 
ADD COLUMN IF NOT EXISTS category_name_en text DEFAULT '' NOT NULL,
ADD COLUMN IF NOT EXISTS category_name_ar text DEFAULT '' NOT NULL;

-- Add active status flag
ALTER TABLE flyer_products 
ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;

-- ============================================
-- STEP 2: Create indexes for foreign keys
-- ============================================

CREATE INDEX IF NOT EXISTS idx_flyer_products_category_id 
ON flyer_products(category_id);

CREATE INDEX IF NOT EXISTS idx_flyer_products_tax_category_id 
ON flyer_products(tax_category_id);

CREATE INDEX IF NOT EXISTS idx_flyer_products_unit_id 
ON flyer_products(unit_id);

CREATE INDEX IF NOT EXISTS idx_flyer_products_product_serial 
ON flyer_products(product_serial);

CREATE INDEX IF NOT EXISTS idx_flyer_products_barcode 
ON flyer_products(barcode);

CREATE INDEX IF NOT EXISTS idx_flyer_products_is_active 
ON flyer_products(is_active);

-- ============================================
-- STEP 3: Add foreign key constraints
-- ============================================

-- Foreign key to product_categories
ALTER TABLE flyer_products
ADD CONSTRAINT fk_flyer_products_category
FOREIGN KEY (category_id) 
REFERENCES product_categories(id)
ON DELETE SET NULL;

-- Foreign key to tax_categories (if table exists)
-- Note: Uncomment if tax_categories table exists
-- ALTER TABLE flyer_products
-- ADD CONSTRAINT fk_flyer_products_tax_category
-- FOREIGN KEY (tax_category_id) 
-- REFERENCES tax_categories(id)
-- ON DELETE SET NULL;

-- Foreign key to product_units
ALTER TABLE flyer_products
ADD CONSTRAINT fk_flyer_products_unit
FOREIGN KEY (unit_id) 
REFERENCES product_units(id)
ON DELETE SET NULL;

-- ============================================
-- STEP 4: Add triggers for automatic calculations
-- ============================================

-- Function to calculate profit and profit_percentage
CREATE OR REPLACE FUNCTION calculate_flyer_product_profit()
RETURNS TRIGGER AS $$
BEGIN
  -- Calculate profit amount
  NEW.profit := NEW.sale_price - NEW.cost;
  
  -- Calculate profit percentage
  IF NEW.cost > 0 THEN
    NEW.profit_percentage := ((NEW.sale_price - NEW.cost) / NEW.cost) * 100;
  ELSE
    NEW.profit_percentage := 0;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for INSERT and UPDATE
DROP TRIGGER IF EXISTS trigger_calculate_flyer_product_profit ON flyer_products;
CREATE TRIGGER trigger_calculate_flyer_product_profit
  BEFORE INSERT OR UPDATE OF sale_price, cost
  ON flyer_products
  FOR EACH ROW
  EXECUTE FUNCTION calculate_flyer_product_profit();

-- ============================================
-- STEP 5: Update existing rows with default values
-- ============================================

-- Generate product_serial for existing records (if null)
-- Format: FP-{sequential-number} for Flyer Product
DO $$
DECLARE
  rec RECORD;
  counter INTEGER := 1;
BEGIN
  FOR rec IN 
    SELECT id FROM flyer_products 
    WHERE product_serial IS NULL 
    ORDER BY created_at, id
  LOOP
    UPDATE flyer_products 
    SET product_serial = 'FP-' || LPAD(counter::text, 6, '0')
    WHERE id = rec.id;
    counter := counter + 1;
  END LOOP;
END $$;

-- Make product_serial NOT NULL after populating
ALTER TABLE flyer_products 
ALTER COLUMN product_serial SET NOT NULL;

-- Add unique constraint on product_serial
ALTER TABLE flyer_products
ADD CONSTRAINT uq_flyer_products_product_serial 
UNIQUE (product_serial);

-- Update category names from parent_category/sub_category if empty
UPDATE flyer_products
SET 
  category_name_en = COALESCE(sub_category, parent_category, ''),
  category_name_ar = COALESCE(sub_category, parent_category, '')
WHERE category_name_en = '' OR category_name_ar = '';

-- Copy unit_name to unit_name_en if null
UPDATE flyer_products
SET unit_name_en = unit_name
WHERE unit_name_en IS NULL AND unit_name IS NOT NULL;

-- ============================================
-- STEP 6: Add comments for documentation
-- ============================================

COMMENT ON COLUMN flyer_products.product_serial IS 'Unique serial identifier for the product';
COMMENT ON COLUMN flyer_products.sale_price IS 'Selling price to customers';
COMMENT ON COLUMN flyer_products.cost IS 'Cost/purchase price of the product';
COMMENT ON COLUMN flyer_products.profit IS 'Calculated profit amount (sale_price - cost)';
COMMENT ON COLUMN flyer_products.profit_percentage IS 'Calculated profit percentage';
COMMENT ON COLUMN flyer_products.current_stock IS 'Current inventory stock level';
COMMENT ON COLUMN flyer_products.category_id IS 'Foreign key to product_categories table';
COMMENT ON COLUMN flyer_products.tax_category_id IS 'Foreign key to tax_categories table';
COMMENT ON COLUMN flyer_products.tax_percentage IS 'Tax rate percentage for this product';
COMMENT ON COLUMN flyer_products.unit_id IS 'Foreign key to product_units table';
COMMENT ON COLUMN flyer_products.unit_qty IS 'Quantity per unit (e.g., 12 for dozen)';
COMMENT ON COLUMN flyer_products.is_active IS 'Whether product is active and visible in customer app';

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check column additions
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'flyer_products'
-- ORDER BY ordinal_position;

-- Check indexes
-- SELECT indexname, indexdef
-- FROM pg_indexes
-- WHERE tablename = 'flyer_products';

-- Check foreign keys
-- SELECT conname, contype, confrelid::regclass, conkey
-- FROM pg_constraint
-- WHERE conrelid = 'flyer_products'::regclass;
