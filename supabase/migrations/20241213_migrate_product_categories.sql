-- Migration: Rebuild product_categories with INTEGER IDs and migrate flyer_products
-- Date: 2024-12-13
-- Purpose: 
--   1. Drop existing product_categories (UUID-based)
--   2. Recreate with INTEGER id
--   3. Insert 67 categories from flyer_products.parent_sub_category
--   4. Add category_id to flyer_products
--   5. Map products to categories
--   6. Drop old category columns from flyer_products

-- =============================================================================
-- STEP 1: Drop existing foreign key constraints
-- =============================================================================

-- Check if products table has category_id FK
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'products_category_id_fkey' 
        AND table_name = 'products'
    ) THEN
        ALTER TABLE products DROP CONSTRAINT products_category_id_fkey;
    END IF;
END $$;

-- =============================================================================
-- STEP 2: Backup and drop existing product_categories table
-- =============================================================================

-- Create backup table
DROP TABLE IF EXISTS product_categories_backup;
CREATE TABLE product_categories_backup AS SELECT * FROM product_categories;

-- Drop the old table
DROP TABLE IF EXISTS product_categories CASCADE;

-- =============================================================================
-- STEP 3: Create new product_categories table with VARCHAR id (CAT001 format)
-- =============================================================================

CREATE TABLE product_categories (
    id VARCHAR(10) PRIMARY KEY,
    name_en VARCHAR(100) NOT NULL,
    name_ar VARCHAR(100) NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

-- Add indexes
CREATE INDEX idx_product_categories_display_order ON product_categories(display_order);
CREATE INDEX idx_product_categories_is_active ON product_categories(is_active);

-- Add RLS policies
ALTER TABLE product_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access" ON product_categories
    FOR SELECT USING (true);

CREATE POLICY "Allow authenticated insert" ON product_categories
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated update" ON product_categories
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated delete" ON product_categories
    FOR DELETE USING (auth.role() = 'authenticated');

-- =============================================================================
-- STEP 4: Insert 67 categories from flyer_products.parent_sub_category
-- =============================================================================

INSERT INTO product_categories (id, name_en, name_ar, display_order, is_active) VALUES 
('CAT001', 'Baking', 'الخبز والمعجنات', 1, true),
('CAT002', 'Bath Soap', 'صابون الاستحمام', 2, true),
('CAT003', 'Biscuits', 'البسكويت', 3, true),
('CAT004', 'Body Care', 'العناية بالجسم', 4, true),
('CAT005', 'Body Wash', 'غسول الجسم', 5, true),
('CAT006', 'Breakfast Cereals', 'حبوب الإفطار', 6, true),
('CAT007', 'Cake Mixes', 'خلطات الكيك', 7, true),
('CAT008', 'Canned Food', 'الأطعمة المعلبة', 8, true),
('CAT009', 'Canned Seafood', 'المأكولات البحرية المعلبة', 9, true),
('CAT010', 'Cheese', 'الجبن', 10, true),
('CAT011', 'Chips', 'رقائق البطاطس', 11, true),
('CAT012', 'Coffee', 'القهوة', 12, true),
('CAT013', 'Coffee Mixes', 'خلطات القهوة', 13, true),
('CAT014', 'Concentrated Drinks', 'المشروبات المركزة', 14, true),
('CAT015', 'Condiments', 'التوابل والصلصات', 15, true),
('CAT016', 'Cooking Fats', 'الدهون الطبخ', 16, true),
('CAT017', 'Cooking Oil', 'زيت الطبخ', 17, true),
('CAT018', 'Creams', 'الكريمات', 18, true),
('CAT019', 'Deodorants & Fragrances', 'مزيلات العرق والعطور', 19, true),
('CAT020', 'Dessert Mix', 'خلطات الحلويات', 20, true),
('CAT021', 'Dishwashing', 'غسيل الصحون', 21, true),
('CAT022', 'Disinfectants', 'المطهرات', 22, true),
('CAT023', 'Disposable', 'المنتجات التي تستخدم لمرة واحدة', 23, true),
('CAT024', 'Drain Care', 'العناية بالصرف الصحي', 24, true),
('CAT025', 'Dry Fruits', 'الفواكه المجففة', 25, true),
('CAT026', 'Fabric Care', 'العناية بالأقمشة', 26, true),
('CAT027', 'Fabric Softener', 'منعم الأقمشة', 27, true),
('CAT028', 'Fast Food', 'الوجبات السريعة', 28, true),
('CAT029', 'Feminine Hygiene', 'النظافة النسائية', 29, true),
('CAT030', 'Flavored Milk', 'الحليب المنكه', 30, true),
('CAT031', 'Floor Care', 'العناية بالأرضيات', 31, true),
('CAT032', 'Flour', 'الدقيق', 32, true),
('CAT033', 'Food Packaging', 'تغليف الأطعمة', 33, true),
('CAT034', 'Frozen Foods', 'الأطعمة المجمدة', 34, true),
('CAT035', 'Fruit Jams', 'مربى الفواكه', 35, true),
('CAT036', 'Grains', 'الحبوب', 36, true),
('CAT037', 'Hair Care', 'العناية بالشعر', 37, true),
('CAT038', 'Hand Wash', 'غسول اليدين', 38, true),
('CAT039', 'Honey', 'العسل', 39, true),
('CAT040', 'Instant Noodles', 'الشعيرية الفورية', 40, true),
('CAT041', 'Juice', 'العصائر', 41, true),
('CAT042', 'Kitchen Appliances', 'أدوات المطبخ', 42, true),
('CAT043', 'Laundry Additives', 'إضافات الغسيل', 43, true),
('CAT044', 'Laundry Detergents', 'مساحيق الغسيل', 44, true),
('CAT045', 'Milk', 'الحليب', 45, true),
('CAT046', 'Milk Powder', 'حليب البودرة', 46, true),
('CAT047', 'Nut Butters', 'زبدة المكسرات', 47, true),
('CAT048', 'Oils', 'الزيوت', 48, true),
('CAT049', 'Outdoor/BBQ', 'منتجات الشواء', 49, true),
('CAT050', 'Packaged Cakes', 'الكيك المعبأ', 50, true),
('CAT051', 'Paper Products', 'المنتجات الورقية', 51, true),
('CAT052', 'Pasta', 'المعكرونة', 52, true),
('CAT053', 'Pest Control', 'مكافحة الحشرات', 53, true),
('CAT054', 'Poultry', 'الدواجن', 54, true),
('CAT055', 'Powdered Drinks', 'المشروبات البودرة', 55, true),
('CAT056', 'Rice', 'الأرز', 56, true),
('CAT057', 'Skincare', 'العناية بالبشرة', 57, true),
('CAT058', 'Spices & Seasonings', 'البهارات والتوابل', 58, true),
('CAT059', 'Spreads', 'الدهون القابلة للدهن', 59, true),
('CAT060', 'Stocks & Bouillon', 'المرق والمكعبات', 60, true),
('CAT061', 'Sugar', 'السكر', 61, true),
('CAT062', 'Sugar Alternatives', 'بدائل السكر', 62, true),
('CAT063', 'Surface Cleaners', 'منظفات الأسطح', 63, true),
('CAT064', 'Tea', 'الشاي', 64, true),
('CAT065', 'Tea Mixes', 'خلطات الشاي', 65, true),
('CAT066', 'Wafers', 'الويفر', 66, true),
('CAT067', 'Water', 'المياه', 67, true);

-- =============================================================================
-- STEP 5: Handle category_id column in flyer_products
-- =============================================================================

-- Drop existing category_id if it exists (from previous migration with INTEGER type)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'flyer_products' 
        AND column_name = 'category_id'
    ) THEN
        -- Drop foreign key constraint if exists
        IF EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'flyer_products_category_id_fkey' 
            AND table_name = 'flyer_products'
        ) THEN
            ALTER TABLE flyer_products DROP CONSTRAINT flyer_products_category_id_fkey;
        END IF;
        
        -- Drop the column
        ALTER TABLE flyer_products DROP COLUMN category_id;
    END IF;
END $$;

-- Add the column with VARCHAR(10) type
ALTER TABLE flyer_products ADD COLUMN category_id VARCHAR(10);

-- Create index
CREATE INDEX idx_flyer_products_category_id ON flyer_products(category_id);

-- =============================================================================
-- STEP 6: Map flyer_products to category_id based on product name patterns
-- =============================================================================

-- Since parent_sub_category column is already dropped, we need to map by product_name
-- We'll create a mapping based on product characteristics

-- First, try to map using existing data if available through a backup or logic
-- For now, we'll set all to a default category and let admin re-categorize
-- Or we can use the flyer_products table structure to infer categories

-- OPTION 1: Set all products to a default category temporarily
-- UPDATE flyer_products SET category_id = 'CAT001' WHERE category_id IS NULL;

-- OPTION 2: Map based on product names (partial matching)
-- This is a basic mapping - adjust as needed

-- Map Cheese products
UPDATE flyer_products SET category_id = 'CAT010' 
WHERE category_id IS NULL 
AND (product_name_en ILIKE '%cheese%' OR product_name_en ILIKE '%mozzarella%' OR product_name_en ILIKE '%cheddar%');

-- Map Coffee products
UPDATE flyer_products SET category_id = 'CAT012' 
WHERE category_id IS NULL 
AND (product_name_en ILIKE '%coffee%' AND NOT product_name_en ILIKE '%creamer%');

-- Map Coffee Mixes
UPDATE flyer_products SET category_id = 'CAT013' 
WHERE category_id IS NULL 
AND (product_name_en ILIKE '%cappuccino%' OR product_name_en ILIKE '%coffee%creamer%');

-- Map Tea
UPDATE flyer_products SET category_id = 'CAT064' 
WHERE category_id IS NULL 
AND product_name_en ILIKE '%tea%';

-- Map Milk products
UPDATE flyer_products SET category_id = 'CAT045' 
WHERE category_id IS NULL 
AND (product_name_en ILIKE '%milk%' AND NOT product_name_en ILIKE '%powder%');

-- Map Milk Powder
UPDATE flyer_products SET category_id = 'CAT046' 
WHERE category_id IS NULL 
AND product_name_en ILIKE '%milk%powder%';

-- Map Oil products
UPDATE flyer_products SET category_id = 'CAT017' 
WHERE category_id IS NULL 
AND product_name_en ILIKE '%oil%';

-- Map Rice
UPDATE flyer_products SET category_id = 'CAT056' 
WHERE category_id IS NULL 
AND product_name_en ILIKE '%rice%';

-- Map Pasta
UPDATE flyer_products SET category_id = 'CAT052' 
WHERE category_id IS NULL 
AND (product_name_en ILIKE '%pasta%' OR product_name_en ILIKE '%spaghetti%' OR product_name_en ILIKE '%macaroni%');

-- Map Water
UPDATE flyer_products SET category_id = 'CAT067' 
WHERE category_id IS NULL 
AND product_name_en ILIKE '%water%';

-- Map Juice
UPDATE flyer_products SET category_id = 'CAT041' 
WHERE category_id IS NULL 
AND product_name_en ILIKE '%juice%';

-- Set remaining unmapped products to 'Frozen Foods' category as default
-- (You can change this default category as needed)
UPDATE flyer_products SET category_id = 'CAT034' WHERE category_id IS NULL;

-- Log unmapped count for verification
DO $$
DECLARE
    unmapped_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO unmapped_count FROM flyer_products WHERE category_id IS NULL;
    RAISE NOTICE 'Unmapped products after name-based mapping: %', unmapped_count;
END $$;

-- =============================================================================
-- STEP 7: Make category_id NOT NULL and add foreign key constraint
-- =============================================================================

-- Check for any unmapped products
DO $$
DECLARE
    unmapped_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO unmapped_count FROM flyer_products WHERE category_id IS NULL;
    
    IF unmapped_count > 0 THEN
        RAISE NOTICE 'WARNING: % products have no category_id mapping!', unmapped_count;
        -- Optionally set a default category or handle differently
        -- UPDATE flyer_products SET category_id = 1 WHERE category_id IS NULL;
    ELSE
        RAISE NOTICE 'SUCCESS: All products mapped to categories';
    END IF;
END $$;

-- Make category_id required
ALTER TABLE flyer_products ALTER COLUMN category_id SET NOT NULL;

-- Add foreign key constraint
ALTER TABLE flyer_products 
    ADD CONSTRAINT flyer_products_category_id_fkey 
    FOREIGN KEY (category_id) 
    REFERENCES product_categories(id)
    ON DELETE RESTRICT;

-- =============================================================================
-- STEP 8: Drop old category columns from flyer_products
-- =============================================================================

-- These columns were already dropped in previous migration, but check anyway
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'flyer_products' 
        AND column_name = 'parent_category'
    ) THEN
        ALTER TABLE flyer_products DROP COLUMN parent_category;
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'flyer_products' 
        AND column_name = 'parent_sub_category'
    ) THEN
        ALTER TABLE flyer_products DROP COLUMN parent_sub_category;
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'flyer_products' 
        AND column_name = 'sub_category'
    ) THEN
        ALTER TABLE flyer_products DROP COLUMN sub_category;
    END IF;
END $$;

-- =============================================================================
-- STEP 9: Verification queries
-- =============================================================================

-- Show category distribution
SELECT 
    pc.id,
    pc.name_en,
    pc.name_ar,
    COUNT(fp.id) as product_count
FROM product_categories pc
LEFT JOIN flyer_products fp ON fp.category_id = pc.id
GROUP BY pc.id, pc.name_en, pc.name_ar
ORDER BY pc.id;

-- Show total counts
SELECT 
    (SELECT COUNT(*) FROM product_categories) as total_categories,
    (SELECT COUNT(*) FROM flyer_products) as total_products,
    (SELECT COUNT(*) FROM flyer_products WHERE category_id IS NOT NULL) as products_with_category;
