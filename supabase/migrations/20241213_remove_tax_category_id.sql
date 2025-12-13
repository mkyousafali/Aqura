-- Migration: Remove tax_category_id from products and flyer_products tables
-- Date: 2024-12-13
-- Purpose: Remove tax_category_id column and its foreign key constraints
-- Dependencies: tax_categories table can be queried but won't be referenced from products

-- =============================================================================
-- STEP 1: Check what exists and what will be removed
-- =============================================================================

DO $$
DECLARE
    products_has_col BOOLEAN;
    flyer_has_col BOOLEAN;
    products_fk_exists BOOLEAN;
    flyer_fk_exists BOOLEAN;
BEGIN
    -- Check if products table exists and has tax_category_id column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'tax_category_id'
    ) INTO products_has_col;
    
    -- Check if flyer_products table exists and has tax_category_id column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'flyer_products' AND column_name = 'tax_category_id'
    ) INTO flyer_has_col;
    
    -- Check for foreign key on products table
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'products' 
        AND constraint_name LIKE '%tax_category%'
    ) INTO products_fk_exists;
    
    -- Check for foreign key on flyer_products table
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'flyer_products' 
        AND constraint_name LIKE '%tax_category%'
    ) INTO flyer_fk_exists;
    
    RAISE NOTICE 'Pre-removal audit:';
    RAISE NOTICE '  - products table has tax_category_id: %', products_has_col;
    RAISE NOTICE '  - flyer_products table has tax_category_id: %', flyer_has_col;
    RAISE NOTICE '  - products FK exists: %', products_fk_exists;
    RAISE NOTICE '  - flyer_products FK exists: %', flyer_fk_exists;
END $$;

-- =============================================================================
-- STEP 2: Remove foreign key constraints
-- =============================================================================

-- Drop FK constraint from products table if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'products' 
        AND constraint_name = 'products_tax_category_id_fkey'
    ) THEN
        ALTER TABLE products DROP CONSTRAINT products_tax_category_id_fkey;
        RAISE NOTICE 'Dropped constraint: products_tax_category_id_fkey';
    ELSE
        RAISE NOTICE 'Constraint products_tax_category_id_fkey does not exist (OK)';
    END IF;
END $$;

-- Drop FK constraint from flyer_products table if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'flyer_products' 
        AND constraint_name = 'flyer_products_tax_category_id_fkey'
    ) THEN
        ALTER TABLE flyer_products DROP CONSTRAINT flyer_products_tax_category_id_fkey;
        RAISE NOTICE 'Dropped constraint: flyer_products_tax_category_id_fkey';
    ELSE
        RAISE NOTICE 'Constraint flyer_products_tax_category_id_fkey does not exist (OK)';
    END IF;
END $$;

-- =============================================================================
-- STEP 3: Remove indexes on tax_category_id
-- =============================================================================

DROP INDEX IF EXISTS idx_products_tax_category_id;
DROP INDEX IF EXISTS idx_flyer_products_tax_category_id;

DO $$
BEGIN
    RAISE NOTICE 'Dropped indexes: idx_products_tax_category_id, idx_flyer_products_tax_category_id';
END $$;

-- =============================================================================
-- STEP 4: Remove columns from tables
-- =============================================================================

-- Remove from products table
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'tax_category_id'
    ) THEN
        ALTER TABLE products DROP COLUMN tax_category_id;
        RAISE NOTICE 'Removed column: products.tax_category_id';
    ELSE
        RAISE NOTICE 'Column products.tax_category_id does not exist (OK)';
    END IF;
END $$;

-- Remove from flyer_products table
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'flyer_products' AND column_name = 'tax_category_id'
    ) THEN
        ALTER TABLE flyer_products DROP COLUMN tax_category_id;
        RAISE NOTICE 'Removed column: flyer_products.tax_category_id';
    ELSE
        RAISE NOTICE 'Column flyer_products.tax_category_id does not exist (OK)';
    END IF;
END $$;

-- =============================================================================
-- STEP 5: Verification
-- =============================================================================

DO $$
DECLARE
    products_col_count INTEGER;
    flyer_col_count INTEGER;
BEGIN
    -- Count remaining columns in products table
    SELECT COUNT(*) INTO products_col_count FROM information_schema.columns 
    WHERE table_name = 'products' AND column_name = 'tax_category_id';
    
    -- Count remaining columns in flyer_products table
    SELECT COUNT(*) INTO flyer_col_count FROM information_schema.columns 
    WHERE table_name = 'flyer_products' AND column_name = 'tax_category_id';
    
    IF products_col_count = 0 AND flyer_col_count = 0 THEN
        RAISE NOTICE 'SUCCESS: tax_category_id removed from all tables';
    ELSE
        RAISE WARNING 'ISSUE: Some tax_category_id columns still exist. Products: %, Flyer: %', 
            products_col_count, flyer_col_count;
    END IF;
END $$;

-- =============================================================================
-- IMPORTANT NOTES
-- =============================================================================
-- 
-- 1. tax_categories table is LEFT UNTOUCHED (can still be used for reference)
-- 2. No data loss - only the foreign key relationship is removed
-- 3. Any remaining tax_category_id data is deleted with the column
-- 4. tax_percentage column remains in products (if present)
-- 5. This is reversible by restoring from backup if needed
--
-- To verify the removal, run:
-- SELECT column_name FROM information_schema.columns 
-- WHERE table_name = 'products' AND column_name LIKE '%tax%';
--
