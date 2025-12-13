-- Migration: Rebuild tax_categories with VARCHAR IDs
-- Date: 2024-12-13
-- Purpose: 
--   1. Drop existing tax_categories (UUID-based)
--   2. Recreate with VARCHAR id (TAX001 format)
--   3. Insert default tax category
--   4. Update flyer_products with tax_category_id

-- =============================================================================
-- STEP 1: Drop existing foreign key constraints
-- =============================================================================

-- Check if products table has tax_category_id FK
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'products_tax_category_id_fkey' 
        AND table_name = 'products'
    ) THEN
        ALTER TABLE products DROP CONSTRAINT products_tax_category_id_fkey;
    END IF;
END $$;

-- Check if flyer_products table has tax_category_id FK
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'flyer_products_tax_category_id_fkey' 
        AND table_name = 'flyer_products'
    ) THEN
        ALTER TABLE flyer_products DROP CONSTRAINT flyer_products_tax_category_id_fkey;
    END IF;
END $$;

-- =============================================================================
-- STEP 2: Backup and drop existing tax_categories table
-- =============================================================================

-- Create backup table
DROP TABLE IF EXISTS tax_categories_backup;
CREATE TABLE tax_categories_backup AS SELECT * FROM tax_categories;

-- Drop the old table
DROP TABLE IF EXISTS tax_categories CASCADE;

-- =============================================================================
-- STEP 3: Create new tax_categories table with VARCHAR id (TAX001 format)
-- =============================================================================

CREATE TABLE tax_categories (
    id VARCHAR(10) PRIMARY KEY,
    name_en VARCHAR(100) NOT NULL,
    name_ar VARCHAR(100) NOT NULL,
    tax_percentage DECIMAL(5,2) NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

-- Add indexes
CREATE INDEX idx_tax_categories_is_active ON tax_categories(is_active);
CREATE INDEX idx_tax_categories_tax_percentage ON tax_categories(tax_percentage);

-- Add RLS policies
ALTER TABLE tax_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access" ON tax_categories
    FOR SELECT USING (true);

CREATE POLICY "Allow authenticated insert" ON tax_categories
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated update" ON tax_categories
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated delete" ON tax_categories
    FOR DELETE USING (auth.role() = 'authenticated');

-- =============================================================================
-- STEP 4: Insert default tax category
-- =============================================================================

-- Insert default 0% tax category (can be updated via UI)
INSERT INTO tax_categories (id, name_en, name_ar, tax_percentage, is_active) VALUES 
('TAX001', 'No Tax', 'بدون ضريبة', 0, true);

-- Optionally add common tax rates (can be enabled/disabled via UI)
-- INSERT INTO tax_categories (id, name_en, name_ar, tax_percentage, is_active) VALUES 
-- ('TAX002', 'VAT 5%', 'ضريبة القيمة المضافة 5%', 5, false),
-- ('TAX003', 'VAT 15%', 'ضريبة القيمة المضافة 15%', 15, false);

-- =============================================================================
-- STEP 5: Update flyer_products with default tax category
-- =============================================================================

-- Set all products to default tax category
UPDATE flyer_products SET tax_category_id = 'TAX001' WHERE tax_category_id IS NULL;

-- Make tax_category_id required
ALTER TABLE flyer_products ALTER COLUMN tax_category_id SET NOT NULL;

-- =============================================================================
-- STEP 6: Add foreign key constraint
-- =============================================================================

ALTER TABLE flyer_products 
    ADD CONSTRAINT flyer_products_tax_category_id_fkey 
    FOREIGN KEY (tax_category_id) 
    REFERENCES tax_categories(id)
    ON DELETE RESTRICT;

-- =============================================================================
-- STEP 7: Verification
-- =============================================================================

-- Show all tax categories
SELECT * FROM tax_categories ORDER BY id;

-- Show product distribution by tax category
SELECT 
    tc.id,
    tc.name_en,
    tc.name_ar,
    tc.tax_percentage,
    COUNT(fp.id) as product_count
FROM tax_categories tc
LEFT JOIN flyer_products fp ON fp.tax_category_id = tc.id
GROUP BY tc.id, tc.name_en, tc.name_ar, tc.tax_percentage
ORDER BY tc.id;

-- Show total counts
SELECT 
    (SELECT COUNT(*) FROM tax_categories) as total_tax_categories,
    (SELECT COUNT(*) FROM flyer_products) as total_products,
    (SELECT COUNT(*) FROM flyer_products WHERE tax_category_id IS NOT NULL) as products_with_tax;
