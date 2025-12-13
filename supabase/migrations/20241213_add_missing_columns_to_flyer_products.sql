-- Migration: Add missing columns to flyer_products for products table compatibility
-- Date: 2024-12-13
-- Purpose: 
--   1. Add missing columns from products table to flyer_products
--   2. Set up tax_category_id relationship
--   3. Add is_customer_product boolean flag
--   4. Prepare flyer_products for rename to products

-- =============================================================================
-- STEP 1: Add missing columns to flyer_products
-- =============================================================================

-- Add pricing and inventory columns
ALTER TABLE flyer_products ADD COLUMN IF NOT EXISTS sale_price DECIMAL(10,2) DEFAULT 0;
ALTER TABLE flyer_products ADD COLUMN IF NOT EXISTS cost DECIMAL(10,2) DEFAULT 0;
ALTER TABLE flyer_products ADD COLUMN IF NOT EXISTS profit DECIMAL(10,2) DEFAULT 0;
ALTER TABLE flyer_products ADD COLUMN IF NOT EXISTS profit_percentage DECIMAL(5,2) DEFAULT 0;
ALTER TABLE flyer_products ADD COLUMN IF NOT EXISTS current_stock INTEGER DEFAULT 0;

-- Add quantity management columns
ALTER TABLE flyer_products ADD COLUMN IF NOT EXISTS unit_qty DECIMAL(10,2) DEFAULT 1;
ALTER TABLE flyer_products ADD COLUMN IF NOT EXISTS minim_qty INTEGER DEFAULT 1;
ALTER TABLE flyer_products ADD COLUMN IF NOT EXISTS minimum_qty_alert INTEGER DEFAULT 10;
ALTER TABLE flyer_products ADD COLUMN IF NOT EXISTS maximum_qty INTEGER DEFAULT 1000;

-- Add tax category reference (VARCHAR to match new tax_categories structure)
ALTER TABLE flyer_products ADD COLUMN IF NOT EXISTS tax_category_id VARCHAR(10);

-- Add status flag
ALTER TABLE flyer_products ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Add customer product flag (new feature!)
ALTER TABLE flyer_products ADD COLUMN IF NOT EXISTS is_customer_product BOOLEAN DEFAULT false;

-- =============================================================================
-- STEP 2: Create indexes for new columns
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_flyer_products_sale_price ON flyer_products(sale_price);
CREATE INDEX IF NOT EXISTS idx_flyer_products_is_active ON flyer_products(is_active);
CREATE INDEX IF NOT EXISTS idx_flyer_products_is_customer_product ON flyer_products(is_customer_product);
CREATE INDEX IF NOT EXISTS idx_flyer_products_tax_category_id ON flyer_products(tax_category_id);
CREATE INDEX IF NOT EXISTS idx_flyer_products_current_stock ON flyer_products(current_stock);

-- =============================================================================
-- STEP 3: Create trigger for automatic profit calculation
-- =============================================================================

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS calculate_profit_trigger ON flyer_products;
DROP FUNCTION IF EXISTS calculate_profit();

-- Create function to calculate profit
CREATE OR REPLACE FUNCTION calculate_profit()
RETURNS TRIGGER AS $$
BEGIN
    -- Calculate profit
    NEW.profit = NEW.sale_price - NEW.cost;
    
    -- Calculate profit percentage
    IF NEW.cost > 0 THEN
        NEW.profit_percentage = ((NEW.sale_price - NEW.cost) / NEW.cost) * 100;
    ELSE
        NEW.profit_percentage = 0;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER calculate_profit_trigger
    BEFORE INSERT OR UPDATE OF sale_price, cost
    ON flyer_products
    FOR EACH ROW
    EXECUTE FUNCTION calculate_profit();

-- =============================================================================
-- STEP 4: Set default values for existing products
-- =============================================================================

-- Set all existing products as active
UPDATE flyer_products SET is_active = true WHERE is_active IS NULL;

-- Set default tax category to TAX001 (will be created in tax migration)
-- UPDATE flyer_products SET tax_category_id = 'TAX001' WHERE tax_category_id IS NULL;

-- Set all existing products as customer products (can be changed later via UI)
UPDATE flyer_products SET is_customer_product = true WHERE is_customer_product IS NULL;

-- Set default unit quantity
UPDATE flyer_products SET unit_qty = 1 WHERE unit_qty IS NULL;

-- Set default minimum quantity
UPDATE flyer_products SET minim_qty = 1 WHERE minim_qty IS NULL;

-- Set default minimum alert quantity
UPDATE flyer_products SET minimum_qty_alert = 10 WHERE minimum_qty_alert IS NULL;

-- Set default maximum quantity
UPDATE flyer_products SET maximum_qty = 1000 WHERE maximum_qty IS NULL;

-- =============================================================================
-- STEP 5: Add foreign key constraint for tax_category_id (after tax migration)
-- =============================================================================

-- Note: This will be enabled after tax_categories table is migrated
-- ALTER TABLE flyer_products 
--     ADD CONSTRAINT flyer_products_tax_category_id_fkey 
--     FOREIGN KEY (tax_category_id) 
--     REFERENCES tax_categories(id)
--     ON DELETE RESTRICT;

-- =============================================================================
-- STEP 6: Verification
-- =============================================================================

-- Show flyer_products table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'flyer_products'
ORDER BY ordinal_position;

-- Count products by status
SELECT 
    COUNT(*) as total_products,
    COUNT(*) FILTER (WHERE is_active = true) as active_products,
    COUNT(*) FILTER (WHERE is_customer_product = true) as customer_products,
    COUNT(*) FILTER (WHERE tax_category_id IS NOT NULL) as products_with_tax
FROM flyer_products;
