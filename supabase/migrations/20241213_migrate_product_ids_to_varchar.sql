-- Migration: Change flyer_products.id from UUID to VARCHAR
-- Date: 2024-12-13
-- Purpose: 
--   1. Backup existing flyer_products table
--   2. Create new flyer_products with VARCHAR(10) id (PRD0000001 format)
--   3. Migrate all data with new IDs
--   4. Update coupon_products foreign key references
--   5. Recreate indexes, constraints, and RLS policies
-- Format: PRD0000001 supports up to 9,999,999 products

-- =============================================================================
-- STEP 1: Drop foreign key from coupon_products to flyer_products.id
-- =============================================================================

DO $$ 
BEGIN
    -- Drop FK from coupon_products (if exists)
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'coupon_products_flyer_product_id_fkey' 
        AND table_name = 'coupon_products'
    ) THEN
        ALTER TABLE coupon_products DROP CONSTRAINT coupon_products_flyer_product_id_fkey;
        RAISE NOTICE 'Dropped constraint: coupon_products.flyer_product_id → flyer_products.id';
    ELSE
        RAISE NOTICE 'Constraint not found: coupon_products_flyer_product_id_fkey';
    END IF;
END $$;

-- =============================================================================
-- STEP 2: Drop existing foreign key constraints from previous migrations
-- =============================================================================

-- Drop FK from flyer_offer_products to flyer_products barcode
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'flyer_offer_products_product_barcode_fkey' 
        AND table_name = 'flyer_offer_products'
    ) THEN
        ALTER TABLE flyer_offer_products DROP CONSTRAINT flyer_offer_products_product_barcode_fkey;
        RAISE NOTICE 'Dropped constraint: flyer_offer_products_product_barcode_fkey';
    END IF;
END $$;

-- Drop FK from units migration (if exists)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'flyer_products_unit_id_fkey' 
        AND table_name = 'flyer_products'
    ) THEN
        ALTER TABLE flyer_products DROP CONSTRAINT flyer_products_unit_id_fkey;
        RAISE NOTICE 'Dropped constraint: flyer_products_unit_id_fkey';
    END IF;
END $$;

-- Drop FK from tax migration (if exists)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'flyer_products_tax_category_id_fkey' 
        AND table_name = 'flyer_products'
    ) THEN
        ALTER TABLE flyer_products DROP CONSTRAINT flyer_products_tax_category_id_fkey;
        RAISE NOTICE 'Dropped constraint: flyer_products_tax_category_id_fkey';
    END IF;
END $$;

-- Drop FK from category migration (if exists)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'flyer_products_category_id_fkey' 
        AND table_name = 'flyer_products'
    ) THEN
        ALTER TABLE flyer_products DROP CONSTRAINT flyer_products_category_id_fkey;
        RAISE NOTICE 'Dropped constraint: flyer_products_category_id_fkey';
    END IF;
END $$;

-- =============================================================================
-- STEP 3: Backup existing table
-- =============================================================================

DROP TABLE IF EXISTS flyer_products_uuid_backup;
CREATE TABLE flyer_products_uuid_backup AS SELECT * FROM flyer_products;

DO $$ 
BEGIN
    RAISE NOTICE 'Backup created: flyer_products_uuid_backup';
END $$;

-- =============================================================================
-- STEP 4: Create new flyer_products table with VARCHAR id
-- =============================================================================

-- Store old table temporarily
ALTER TABLE flyer_products RENAME TO flyer_products_old;

-- Create new table with VARCHAR(10) id
CREATE TABLE flyer_products (
    id VARCHAR(10) PRIMARY KEY,
    barcode TEXT NOT NULL,
    product_name_en TEXT,
    product_name_ar TEXT,
    image_url TEXT,
    
    -- Category relationship (VARCHAR already migrated)
    category_id VARCHAR(10) REFERENCES product_categories(id) ON DELETE SET NULL,
    
    -- Unit relationship (VARCHAR after units migration)
    unit_id VARCHAR(10),
    unit_qty NUMERIC DEFAULT 1 NOT NULL,
    
    -- Pricing
    sale_price NUMERIC DEFAULT 0 NOT NULL,
    cost NUMERIC DEFAULT 0 NOT NULL,
    profit NUMERIC DEFAULT 0 NOT NULL,
    profit_percentage NUMERIC DEFAULT 0 NOT NULL,
    
    -- Inventory
    current_stock INTEGER DEFAULT 0 NOT NULL,
    minim_qty INTEGER DEFAULT 0 NOT NULL,
    minimum_qty_alert INTEGER DEFAULT 0 NOT NULL,
    maximum_qty INTEGER DEFAULT 0 NOT NULL,
    
    -- Tax relationship (VARCHAR after tax migration)
    tax_category_id VARCHAR(10),
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    is_customer_product BOOLEAN DEFAULT true,
    
    -- Variation support
    is_variation BOOLEAN DEFAULT false NOT NULL,
    parent_product_barcode TEXT,
    variation_group_name_en TEXT,
    variation_group_name_ar TEXT,
    variation_order INTEGER DEFAULT 0,
    variation_image_override TEXT,
    
    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    modified_by UUID REFERENCES auth.users(id),
    modified_at TIMESTAMP WITH TIME ZONE
);

-- =============================================================================
-- STEP 5: Create ID mapping table (UUID → VARCHAR)
-- =============================================================================

CREATE TEMPORARY TABLE product_id_mapping (
    old_uuid_id UUID,
    new_varchar_id VARCHAR(10),
    barcode TEXT
);

-- =============================================================================
-- STEP 6: Migrate data with new VARCHAR IDs (PRD0000001 format)
-- =============================================================================

DO $$
DECLARE
    rec RECORD;
    new_id VARCHAR(10);
    counter INTEGER := 1;
BEGIN
    -- Migrate all products with new IDs
    FOR rec IN 
        SELECT * FROM flyer_products_old 
        ORDER BY created_at, barcode
    LOOP
        -- Generate new ID: PRD0000001, PRD0000002, etc.
        new_id := 'PRD' || LPAD(counter::TEXT, 7, '0');
        
        -- Insert into new table
        INSERT INTO flyer_products (
            id, barcode, product_name_en, product_name_ar, image_url,
            category_id, unit_id, unit_qty,
            sale_price, cost, profit, profit_percentage,
            current_stock, minim_qty, minimum_qty_alert, maximum_qty,
            tax_category_id, is_active, is_customer_product,
            is_variation, parent_product_barcode,
            variation_group_name_en, variation_group_name_ar,
            variation_order, variation_image_override,
            created_at, updated_at, created_by, modified_by, modified_at
        ) VALUES (
            new_id, rec.barcode, rec.product_name_en, rec.product_name_ar, rec.image_url,
            rec.category_id, rec.unit_id, COALESCE(rec.unit_qty, 1),
            COALESCE(rec.sale_price, 0), COALESCE(rec.cost, 0), 
            COALESCE(rec.profit, 0), COALESCE(rec.profit_percentage, 0),
            COALESCE(rec.current_stock, 0), COALESCE(rec.minim_qty, 0), 
            COALESCE(rec.minimum_qty_alert, 0), COALESCE(rec.maximum_qty, 0),
            rec.tax_category_id, COALESCE(rec.is_active, true), 
            COALESCE(rec.is_customer_product, true),
            COALESCE(rec.is_variation, false), rec.parent_product_barcode,
            rec.variation_group_name_en, rec.variation_group_name_ar,
            COALESCE(rec.variation_order, 0), rec.variation_image_override,
            rec.created_at, rec.updated_at, rec.created_by, rec.modified_by, rec.modified_at
        );
        
        -- Store mapping for coupon_products update
        INSERT INTO product_id_mapping (old_uuid_id, new_varchar_id, barcode)
        VALUES (rec.id, new_id, rec.barcode);
        
        counter := counter + 1;
    END LOOP;
    
    RAISE NOTICE 'Migrated % products with new VARCHAR IDs', counter - 1;
END $$;

-- =============================================================================
-- STEP 7: Create indexes
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_flyer_products_barcode ON flyer_products(barcode);
CREATE INDEX IF NOT EXISTS idx_flyer_products_category_id ON flyer_products(category_id);
CREATE INDEX IF NOT EXISTS idx_flyer_products_unit_id ON flyer_products(unit_id);
CREATE INDEX IF NOT EXISTS idx_flyer_products_tax_category_id ON flyer_products(tax_category_id);
CREATE INDEX IF NOT EXISTS idx_flyer_products_is_active ON flyer_products(is_active);
CREATE INDEX IF NOT EXISTS idx_flyer_products_is_customer_product ON flyer_products(is_customer_product);
CREATE INDEX IF NOT EXISTS idx_flyer_products_is_variation ON flyer_products(is_variation);
CREATE INDEX IF NOT EXISTS idx_flyer_products_parent_product_barcode ON flyer_products(parent_product_barcode);
CREATE INDEX IF NOT EXISTS idx_flyer_products_created_at ON flyer_products(created_at);

-- Unique constraint on barcode
CREATE UNIQUE INDEX IF NOT EXISTS uq_flyer_products_barcode ON flyer_products(barcode);

-- =============================================================================
-- STEP 8: Update coupon_products with new VARCHAR IDs
-- =============================================================================

-- First, add a temporary column for new IDs
ALTER TABLE coupon_products ADD COLUMN IF NOT EXISTS flyer_product_id_new VARCHAR(10);

-- Update using the mapping table (UUID → VARCHAR)
DO $$
DECLARE
    update_count INTEGER;
BEGIN
    UPDATE coupon_products cp
    SET flyer_product_id_new = m.new_varchar_id
    FROM product_id_mapping m
    WHERE cp.flyer_product_id::TEXT = m.old_uuid_id::TEXT;
    
    GET DIAGNOSTICS update_count = ROW_COUNT;
    RAISE NOTICE 'Updated % coupon_products records with new VARCHAR IDs', update_count;
END $$;

-- Drop the old UUID column
ALTER TABLE coupon_products DROP COLUMN flyer_product_id;

-- Rename new column to original name
ALTER TABLE coupon_products RENAME COLUMN flyer_product_id_new TO flyer_product_id;

-- =============================================================================
-- STEP 9: Create profit calculation trigger
-- =============================================================================

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

DROP TRIGGER IF EXISTS trigger_calculate_flyer_product_profit ON flyer_products;
CREATE TRIGGER trigger_calculate_flyer_product_profit
  BEFORE INSERT OR UPDATE OF sale_price, cost
  ON flyer_products
  FOR EACH ROW
  EXECUTE FUNCTION calculate_flyer_product_profit();

-- =============================================================================
-- STEP 10: Enable RLS and create policies
-- =============================================================================

ALTER TABLE flyer_products ENABLE ROW LEVEL SECURITY;

-- Public read access for customer app
CREATE POLICY "Allow public read access for active customer products" ON flyer_products
    FOR SELECT USING (is_active = true AND is_customer_product = true);

-- Authenticated users can read all products
CREATE POLICY "Allow authenticated read access" ON flyer_products
    FOR SELECT USING (auth.role() = 'authenticated');

-- Authenticated users can insert
CREATE POLICY "Allow authenticated insert" ON flyer_products
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Authenticated users can update
CREATE POLICY "Allow authenticated update" ON flyer_products
    FOR UPDATE USING (auth.role() = 'authenticated');

-- Authenticated users can delete
CREATE POLICY "Allow authenticated delete" ON flyer_products
    FOR DELETE USING (auth.role() = 'authenticated');

-- =============================================================================
-- STEP 11: Recreate foreign key constraints
-- =============================================================================

-- Category FK (already in CREATE TABLE, but verify)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'flyer_products_category_id_fkey' 
        AND table_name = 'flyer_products'
    ) THEN
        ALTER TABLE flyer_products 
            ADD CONSTRAINT flyer_products_category_id_fkey 
            FOREIGN KEY (category_id) 
            REFERENCES product_categories(id) 
            ON DELETE SET NULL;
        RAISE NOTICE 'Added constraint: flyer_products_category_id_fkey';
    END IF;
END $$;

-- Unit FK (recreate from units migration)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'product_units') THEN
        ALTER TABLE flyer_products 
            ADD CONSTRAINT flyer_products_unit_id_fkey 
            FOREIGN KEY (unit_id) 
            REFERENCES product_units(id) 
            ON DELETE RESTRICT;
        RAISE NOTICE 'Added constraint: flyer_products_unit_id_fkey';
    ELSE
        RAISE NOTICE 'Skipped unit FK: product_units table not found';
    END IF;
END $$;

-- Tax FK (recreate from tax migration)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'tax_categories') THEN
        ALTER TABLE flyer_products 
            ADD CONSTRAINT flyer_products_tax_category_id_fkey 
            FOREIGN KEY (tax_category_id) 
            REFERENCES tax_categories(id) 
            ON DELETE RESTRICT;
        RAISE NOTICE 'Added constraint: flyer_products_tax_category_id_fkey';
    ELSE
        RAISE NOTICE 'Skipped tax FK: tax_categories table not found';
    END IF;
END $$;

-- Coupon FK (recreate with new VARCHAR type)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'coupon_products') THEN
        ALTER TABLE coupon_products 
            ADD CONSTRAINT coupon_products_flyer_product_id_fkey 
            FOREIGN KEY (flyer_product_id) 
            REFERENCES flyer_products(id) 
            ON DELETE CASCADE;
        RAISE NOTICE 'Added constraint: coupon_products_flyer_product_id_fkey (VARCHAR)';
    ELSE
        RAISE NOTICE 'Skipped coupon FK: coupon_products table not found';
    END IF;
END $$;

-- Flyer Offer Products FK (recreate barcode foreign key)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'flyer_offer_products') THEN
        ALTER TABLE flyer_offer_products 
            ADD CONSTRAINT flyer_offer_products_product_barcode_fkey 
            FOREIGN KEY (product_barcode) 
            REFERENCES flyer_products(barcode) 
            ON DELETE CASCADE;
        RAISE NOTICE 'Added constraint: flyer_offer_products_product_barcode_fkey';
    ELSE
        RAISE NOTICE 'Skipped flyer_offer_products FK: table not found';
    END IF;
END $$;

-- =============================================================================
-- STEP 12: Drop old table and cleanup
-- =============================================================================

DROP TABLE flyer_products_old;

-- Mapping table is temporary, will auto-drop at end of transaction

-- =============================================================================
-- STEP 13: Verification
-- =============================================================================

-- Show ID format examples
SELECT id, barcode, product_name_en, created_at 
FROM flyer_products 
ORDER BY id 
LIMIT 10;

-- Show statistics
SELECT 
    COUNT(*) as total_products,
    COUNT(DISTINCT category_id) as unique_categories,
    COUNT(CASE WHEN is_active THEN 1 END) as active_products,
    COUNT(CASE WHEN is_customer_product THEN 1 END) as customer_visible_products,
    COUNT(CASE WHEN is_variation THEN 1 END) as variation_products,
    MIN(id) as first_id,
    MAX(id) as last_id
FROM flyer_products;

-- Show ID format
SELECT 
    'ID Format: PRD0000001 to PRD' || LPAD((SELECT COUNT(*)::TEXT FROM flyer_products), 7, '0') as id_range,
    'Supports up to PRD9999999 (9,999,999 products)' as max_capacity;

-- Verify coupon_products updated
SELECT 
    COUNT(*) as total_coupon_products,
    COUNT(CASE WHEN flyer_product_id LIKE 'PRD%' THEN 1 END) as with_new_varchar_ids
FROM coupon_products;
