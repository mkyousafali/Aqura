-- Migration: Rebuild product_units with VARCHAR IDs and migrate flyer_products
-- Date: 2024-12-13
-- Purpose: 
--   1. Drop existing product_units (UUID-based)
--   2. Recreate with VARCHAR id (UNIT001 format)
--   3. Insert units from flyer_products.unit_name
--   4. Add unit_id to flyer_products
--   5. Map products to units
--   6. Drop unit_name column from flyer_products

-- =============================================================================
-- STEP 1: Drop existing foreign key constraints
-- =============================================================================

-- Check if products table has unit_id FK
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'products_unit_id_fkey' 
        AND table_name = 'products'
    ) THEN
        ALTER TABLE products DROP CONSTRAINT products_unit_id_fkey;
    END IF;
END $$;

-- Check if flyer_products table has unit_id FK
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'flyer_products_unit_id_fkey' 
        AND table_name = 'flyer_products'
    ) THEN
        ALTER TABLE flyer_products DROP CONSTRAINT flyer_products_unit_id_fkey;
    END IF;
END $$;

-- =============================================================================
-- STEP 2: Backup and drop existing product_units table
-- =============================================================================

-- Create backup table
DROP TABLE IF EXISTS product_units_backup;
CREATE TABLE product_units_backup AS SELECT * FROM product_units;

-- Drop the old table
DROP TABLE IF EXISTS product_units CASCADE;

-- =============================================================================
-- STEP 3: Create new product_units table with VARCHAR id (UNIT001 format)
-- =============================================================================

CREATE TABLE product_units (
    id VARCHAR(10) PRIMARY KEY,
    name_en VARCHAR(50) NOT NULL,
    name_ar VARCHAR(50) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

-- Add index
CREATE INDEX idx_product_units_is_active ON product_units(is_active);

-- Add RLS policies
ALTER TABLE product_units ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access" ON product_units
    FOR SELECT USING (true);

CREATE POLICY "Allow authenticated insert" ON product_units
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated update" ON product_units
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated delete" ON product_units
    FOR DELETE USING (auth.role() = 'authenticated');

-- =============================================================================
-- STEP 4: Insert units from flyer_products.unit_name
-- =============================================================================

-- Insert 12 unique units found in flyer_products
INSERT INTO product_units (id, name_en, name_ar, is_active) VALUES 
('UNIT001', 'Piece', 'حبة', true),
('UNIT002', 'Bundle', 'شدة', true),
('UNIT003', 'Packet', 'باكيت', true),
('UNIT004', 'Carton', 'كرتون', true),
('UNIT005', 'Bag', 'كيس', true),
('UNIT006', 'Tray', 'طبق', true),
('UNIT007', 'Pack', 'حزمة', true),
('UNIT008', 'Liter', 'لتر', true),
('UNIT009', 'Gallon', 'جالون', true),
('UNIT010', 'Multi-Pack 5+1', 'عبوة متعددة 5+1', true),
('UNIT011', 'Multi-Pack 7+1', 'عبوة متعددة 7+1', true),
('UNIT012', 'Carton Special', 'كرتون خاص', true);

-- =============================================================================
-- STEP 5: Handle unit_id column in flyer_products
-- =============================================================================

-- Drop existing unit_id if it exists (from any previous migration)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'flyer_products' 
        AND column_name = 'unit_id'
    ) THEN
        -- Drop foreign key constraint if exists
        IF EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'flyer_products_unit_id_fkey' 
            AND table_name = 'flyer_products'
        ) THEN
            ALTER TABLE flyer_products DROP CONSTRAINT flyer_products_unit_id_fkey;
        END IF;
        
        -- Drop the column
        ALTER TABLE flyer_products DROP COLUMN unit_id;
    END IF;
END $$;

-- Add the column with VARCHAR(10) type
ALTER TABLE flyer_products ADD COLUMN unit_id VARCHAR(10);

-- Create index
CREATE INDEX idx_flyer_products_unit_id ON flyer_products(unit_id);

-- =============================================================================
-- STEP 6: Map flyer_products to unit_id based on unit_name (if column exists)
-- =============================================================================

-- Map based on exact Arabic unit_name matches (only if unit_name column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'flyer_products' 
        AND column_name = 'unit_name'
    ) THEN
        -- Map based on unit_name
        UPDATE flyer_products SET unit_id = 'UNIT001' WHERE unit_name = 'حبه';
        UPDATE flyer_products SET unit_id = 'UNIT002' WHERE unit_name = 'شده';
        UPDATE flyer_products SET unit_id = 'UNIT003' WHERE unit_name = 'باكت';
        UPDATE flyer_products SET unit_id = 'UNIT004' WHERE unit_name = 'كرتون';
        UPDATE flyer_products SET unit_id = 'UNIT005' WHERE unit_name = 'كيس';
        UPDATE flyer_products SET unit_id = 'UNIT006' WHERE unit_name = 'طبق';
        UPDATE flyer_products SET unit_id = 'UNIT007' WHERE unit_name = 'PCs';
        UPDATE flyer_products SET unit_id = 'UNIT008' WHERE unit_name = '3.958';
        UPDATE flyer_products SET unit_id = 'UNIT009' WHERE unit_name = '3.8389';
        UPDATE flyer_products SET unit_id = 'UNIT010' WHERE unit_name = '5+1';
        UPDATE flyer_products SET unit_id = 'UNIT011' WHERE unit_name = '7+1';
        UPDATE flyer_products SET unit_id = 'UNIT012' WHERE unit_name = 'كرتون-';
        
        RAISE NOTICE 'Mapped products using unit_name column';
    ELSE
        RAISE NOTICE 'unit_name column does not exist - will set all to default unit';
    END IF;
END $$;

-- Set default unit for any unmapped products
UPDATE flyer_products SET unit_id = 'UNIT001' WHERE unit_id IS NULL;

-- Log unmapped count for verification
DO $$
DECLARE
    unmapped_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO unmapped_count FROM flyer_products WHERE unit_id IS NULL;
    RAISE NOTICE 'Unmapped products after unit mapping: %', unmapped_count;
END $$;

-- =============================================================================
-- STEP 7: Make unit_id NOT NULL and add foreign key constraint
-- =============================================================================

-- Check for any unmapped products
DO $$
DECLARE
    unmapped_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO unmapped_count FROM flyer_products WHERE unit_id IS NULL;
    
    IF unmapped_count > 0 THEN
        RAISE NOTICE 'WARNING: % products have no unit_id mapping!', unmapped_count;
    ELSE
        RAISE NOTICE 'SUCCESS: All products mapped to units';
    END IF;
END $$;

-- Make unit_id required
ALTER TABLE flyer_products ALTER COLUMN unit_id SET NOT NULL;

-- Add foreign key constraint
ALTER TABLE flyer_products 
    ADD CONSTRAINT flyer_products_unit_id_fkey 
    FOREIGN KEY (unit_id) 
    REFERENCES product_units(id)
    ON DELETE RESTRICT;

-- =============================================================================
-- STEP 8: Drop unit_name column from flyer_products
-- =============================================================================

-- Check and drop unit_name column
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'flyer_products' 
        AND column_name = 'unit_name'
    ) THEN
        ALTER TABLE flyer_products DROP COLUMN unit_name;
        RAISE NOTICE 'Dropped unit_name column from flyer_products';
    END IF;
END $$;

-- =============================================================================
-- STEP 9: Verification queries
-- =============================================================================

-- Show unit distribution
SELECT 
    pu.id,
    pu.name_en,
    pu.name_ar,
    COUNT(fp.id) as product_count
FROM product_units pu
LEFT JOIN flyer_products fp ON fp.unit_id = pu.id
GROUP BY pu.id, pu.name_en, pu.name_ar
ORDER BY product_count DESC;

-- Show total counts
SELECT 
    (SELECT COUNT(*) FROM product_units) as total_units,
    (SELECT COUNT(*) FROM flyer_products) as total_products,
    (SELECT COUNT(*) FROM flyer_products WHERE unit_id IS NOT NULL) as products_with_unit;
