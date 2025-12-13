-- Migration: Consolidate Products Table
-- Date: 2024-12-13
-- Purpose: 
--   1. Drop the old products table (22 records, UUID-based)
--   2. Rename flyer_products to products (794 records, VARCHAR PRD-based)
--   3. This completes the product ID migration from UUID to VARCHAR
-- Result: Single products table with PRD0000001-format IDs

-- =============================================================================
-- STEP 1: Verify flyer_products is ready
-- =============================================================================

DO $$
DECLARE
    product_count INTEGER;
    varchar_id_count INTEGER;
BEGIN
    -- Check flyer_products exists and has data
    SELECT COUNT(*) INTO product_count FROM flyer_products;
    
    IF product_count = 0 THEN
        RAISE EXCEPTION 'flyer_products table is empty - migration cannot proceed';
    END IF;
    
    -- Verify all IDs are VARCHAR format (PRD*)
    SELECT COUNT(*) INTO varchar_id_count FROM flyer_products WHERE id LIKE 'PRD%';
    
    IF varchar_id_count <> product_count THEN
        RAISE EXCEPTION 'Not all product IDs are in VARCHAR PRD format - found % of %', varchar_id_count, product_count;
    END IF;
    
    RAISE NOTICE 'Verification passed: % products with VARCHAR IDs ready for rename', product_count;
END $$;

-- =============================================================================
-- STEP 2: Check for dependencies on products table
-- =============================================================================

DO $$
DECLARE
    fk_count INTEGER;
    fk_rec RECORD;
BEGIN
    -- Check for foreign keys referencing products table
    SELECT COUNT(*) INTO fk_count
    FROM information_schema.table_constraints tc
    JOIN information_schema.constraint_column_usage ccu 
        ON tc.constraint_name = ccu.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
        AND ccu.table_name = 'products';
    
    IF fk_count > 0 THEN
        RAISE NOTICE 'Found % foreign key(s) referencing products table:', fk_count;
        
        FOR fk_rec IN 
            SELECT 
                tc.table_name as from_table,
                tc.constraint_name,
                kcu.column_name as from_column,
                ccu.table_name as to_table,
                ccu.column_name as to_column
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu 
                ON tc.constraint_name = kcu.constraint_name
            JOIN information_schema.constraint_column_usage ccu 
                ON tc.constraint_name = ccu.constraint_name
            WHERE tc.constraint_type = 'FOREIGN KEY'
                AND ccu.table_name = 'products'
        LOOP
            RAISE NOTICE '  - %.% (%) -> %.%',
                fk_rec.from_table, fk_rec.from_column, fk_rec.constraint_name,
                fk_rec.to_table, fk_rec.to_column;
        END LOOP;
        
        RAISE NOTICE 'These FKs will be dropped with CASCADE';
    ELSE
        RAISE NOTICE 'No foreign keys reference products table - safe to drop';
    END IF;
END $$;

-- =============================================================================
-- STEP 3: Backup old products table (optional safety measure)
-- =============================================================================

DROP TABLE IF EXISTS products_uuid_backup;
CREATE TABLE products_uuid_backup AS SELECT * FROM products;

DO $$
DECLARE
    backup_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO backup_count FROM products_uuid_backup;
    RAISE NOTICE 'Backed up % records from old products table', backup_count;
END $$;

-- =============================================================================
-- STEP 4: Drop old products table
-- =============================================================================

DROP TABLE IF EXISTS products CASCADE;

DO $$
BEGIN
    RAISE NOTICE 'Dropped old products table (UUID-based)';
END $$;

-- =============================================================================
-- STEP 5: Rename flyer_products to products
-- =============================================================================

ALTER TABLE flyer_products RENAME TO products;

DO $$
BEGIN
    RAISE NOTICE 'Renamed flyer_products to products';
END $$;

-- =============================================================================
-- STEP 6: Drop FK constraints that depend on indexes
-- =============================================================================

-- Drop flyer_offer_products FK that depends on uq_flyer_products_barcode
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'flyer_offer_products_product_barcode_fkey'
        AND table_name = 'flyer_offer_products'
    ) THEN
        ALTER TABLE flyer_offer_products DROP CONSTRAINT flyer_offer_products_product_barcode_fkey;
        RAISE NOTICE 'Dropped FK: flyer_offer_products_product_barcode_fkey (will recreate later)';
    END IF;
END $$;

-- Drop coupon_products FK (will recreate with new name)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'coupon_products_flyer_product_id_fkey'
        AND table_name = 'coupon_products'
    ) THEN
        ALTER TABLE coupon_products DROP CONSTRAINT coupon_products_flyer_product_id_fkey;
        RAISE NOTICE 'Dropped FK: coupon_products_flyer_product_id_fkey (will recreate later)';
    END IF;
END $$;

-- =============================================================================
-- STEP 7: Update index names to match new table name
-- =============================================================================

-- Drop old indexes with flyer_products prefix
DROP INDEX IF EXISTS idx_flyer_products_barcode;
DROP INDEX IF EXISTS idx_flyer_products_category_id;
DROP INDEX IF EXISTS idx_flyer_products_unit_id;
DROP INDEX IF EXISTS idx_flyer_products_tax_category_id;
DROP INDEX IF EXISTS idx_flyer_products_is_active;
DROP INDEX IF EXISTS idx_flyer_products_is_customer_product;
DROP INDEX IF EXISTS idx_flyer_products_is_variation;
DROP INDEX IF EXISTS idx_flyer_products_parent_product_barcode;
DROP INDEX IF EXISTS idx_flyer_products_created_at;
DROP INDEX IF EXISTS uq_flyer_products_barcode;

-- Create new indexes with products prefix
CREATE INDEX idx_products_barcode ON products(barcode);
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_unit_id ON products(unit_id);
CREATE INDEX idx_products_tax_category_id ON products(tax_category_id);
CREATE INDEX idx_products_is_active ON products(is_active);
CREATE INDEX idx_products_is_customer_product ON products(is_customer_product);
CREATE INDEX idx_products_is_variation ON products(is_variation);
CREATE INDEX idx_products_parent_product_barcode ON products(parent_product_barcode);
CREATE INDEX idx_products_created_at ON products(created_at);
CREATE UNIQUE INDEX uq_products_barcode ON products(barcode);

DO $$
BEGIN
    RAISE NOTICE 'Recreated indexes with products table name';
END $$;

-- =============================================================================
-- STEP 8: Update trigger function name (optional - for consistency)
-- =============================================================================

-- The trigger already exists, just verify it's working
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_name = 'trigger_calculate_flyer_product_profit'
        AND event_object_table = 'products'
    ) THEN
        RAISE NOTICE 'Profit calculation trigger active on products table';
    ELSE
        RAISE WARNING 'Profit calculation trigger not found - may need to recreate';
    END IF;
END $$;

-- =============================================================================
-- STEP 9: Verify RLS policies transferred
-- =============================================================================

DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE tablename = 'products';
    
    IF policy_count > 0 THEN
        RAISE NOTICE 'Found % RLS policies on products table', policy_count;
    ELSE
        RAISE WARNING 'No RLS policies found on products table - may need to recreate';
    END IF;
END $$;

-- =============================================================================
-- STEP 10: Recreate foreign key constraints with new table name
-- =============================================================================

-- Recreate coupon_products FK to point to products table
ALTER TABLE coupon_products 
    ADD CONSTRAINT coupon_products_product_id_fkey 
    FOREIGN KEY (flyer_product_id) 
    REFERENCES products(id) 
    ON DELETE CASCADE;

DO $$
BEGIN
    RAISE NOTICE 'Created new FK: coupon_products_product_id_fkey → products(id)';
END $$;

-- Recreate flyer_offer_products FK
ALTER TABLE flyer_offer_products 
    ADD CONSTRAINT flyer_offer_products_product_barcode_fkey 
    FOREIGN KEY (product_barcode) 
    REFERENCES products(barcode) 
    ON DELETE CASCADE;

DO $$
BEGIN
    RAISE NOTICE 'Created new FK: flyer_offer_products_product_barcode_fkey → products(barcode)';
END $$;

-- =============================================================================
-- STEP 11: Final verification
-- =============================================================================

-- Show table structure
SELECT 
    'products' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT category_id) as unique_categories,
    COUNT(CASE WHEN is_active THEN 1 END) as active_products,
    COUNT(CASE WHEN is_customer_product THEN 1 END) as customer_visible,
    COUNT(CASE WHEN is_variation THEN 1 END) as variation_products,
    MIN(id) as first_id,
    MAX(id) as last_id
FROM products;

-- Show ID format
SELECT 
    id, barcode, product_name_en, category_id, unit_id, sale_price, is_active
FROM products 
ORDER BY id 
LIMIT 5;

-- Verify foreign keys
SELECT 
    tc.constraint_name,
    tc.table_name as from_table,
    kcu.column_name as from_column,
    ccu.table_name as to_table,
    ccu.column_name as to_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu 
    ON tc.constraint_name = ccu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND (tc.table_name = 'products' OR ccu.table_name = 'products')
ORDER BY tc.table_name, tc.constraint_name;

DO $$
BEGIN
    RAISE NOTICE '✅ Migration complete: flyer_products renamed to products';
    RAISE NOTICE '✅ All VARCHAR PRD-format IDs preserved';
    RAISE NOTICE '✅ Foreign keys updated';
    RAISE NOTICE '⚠️  Next step: Update code references from .from(''flyer_products'') to .from(''products'')';
END $$;
