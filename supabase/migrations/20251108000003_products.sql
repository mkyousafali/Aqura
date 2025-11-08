-- =============================================
-- PRODUCTS SYSTEM
-- =============================================
-- Date: 2025-11-08
-- Description: Create products table with unit-based entries

-- =============================================
-- 1. CREATE STORAGE BUCKET FOR PRODUCT IMAGES
-- =============================================

-- Create public storage bucket for product images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images',
  'product-images',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- =============================================
-- 2. STORAGE POLICIES FOR PRODUCT IMAGES
-- =============================================

-- Policy: Allow public read access to product images
CREATE POLICY "Public read access for product images"
ON storage.objects FOR SELECT
USING (bucket_id = 'product-images');

-- Policy: Allow authenticated users to upload product images
CREATE POLICY "Authenticated users can upload product images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'product-images');

-- Policy: Allow authenticated users to update product images
CREATE POLICY "Authenticated users can update product images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'product-images');

-- Policy: Allow authenticated users to delete product images
CREATE POLICY "Authenticated users can delete product images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'product-images');

-- =============================================
-- 3. CREATE PRODUCTS TABLE
-- =============================================

CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Product Serial (shared across all units of same product)
    product_serial TEXT NOT NULL,
    
    -- Product Information
    product_name_en TEXT NOT NULL,
    product_name_ar TEXT NOT NULL,
    
    -- Category Information (denormalized for quick access)
    category_id UUID REFERENCES product_categories(id),
    category_name_en TEXT NOT NULL,
    category_name_ar TEXT NOT NULL,
    
    -- Tax Category Information (denormalized)
    tax_category_id UUID REFERENCES tax_categories(id),
    tax_category_name_en TEXT NOT NULL,
    tax_category_name_ar TEXT NOT NULL,
    tax_percentage NUMERIC(5, 2) NOT NULL,
    
    -- Unit Information
    unit_id UUID REFERENCES product_units(id),
    unit_name_en TEXT NOT NULL,
    unit_name_ar TEXT NOT NULL,
    unit_qty NUMERIC(10, 2) NOT NULL DEFAULT 1,
    
    -- Barcode
    barcode TEXT,
    
    -- Pricing (inclusive of tax)
    sale_price NUMERIC(10, 2) NOT NULL,
    cost NUMERIC(10, 2) NOT NULL,
    profit NUMERIC(10, 2) NOT NULL,
    profit_percentage NUMERIC(10, 2) NOT NULL,
    
    -- Stock Quantities
    current_stock INTEGER NOT NULL DEFAULT 0,
    minim_qty INTEGER NOT NULL DEFAULT 0,
    minimum_qty_alert INTEGER NOT NULL DEFAULT 0,
    maximum_qty INTEGER NOT NULL DEFAULT 0,
    
    -- Image
    image_url TEXT,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    
    -- Constraints
    CONSTRAINT unique_product_barcode UNIQUE(barcode),
    CONSTRAINT positive_sale_price CHECK (sale_price >= 0),
    CONSTRAINT positive_cost CHECK (cost >= 0),
    CONSTRAINT positive_unit_qty CHECK (unit_qty > 0),
    CONSTRAINT non_negative_stock CHECK (current_stock >= 0)
);

-- =============================================
-- 4. CREATE INDEXES
-- =============================================

-- Index for product serial (shared by multiple units)
CREATE INDEX idx_products_serial ON products(product_serial);

-- Index for barcode lookups
CREATE INDEX idx_products_barcode ON products(barcode);

-- Index for category filtering
CREATE INDEX idx_products_category ON products(category_id);

-- Index for tax category
CREATE INDEX idx_products_tax_category ON products(tax_category_id);

-- Index for unit
CREATE INDEX idx_products_unit ON products(unit_id);

-- Index for active products
CREATE INDEX idx_products_active ON products(is_active);

-- Index for created date
CREATE INDEX idx_products_created_at ON products(created_at);

-- Composite index for product name searches
CREATE INDEX idx_products_name_en ON products(product_name_en);
CREATE INDEX idx_products_name_ar ON products(product_name_ar);

-- =============================================
-- 5. ENABLE ROW LEVEL SECURITY
-- =============================================

ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Policy: Allow public read access to active products
CREATE POLICY "Public read access to active products"
ON products FOR SELECT
USING (is_active = true);

-- Policy: Allow authenticated users to read all products
CREATE POLICY "Authenticated users can read all products"
ON products FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert products
CREATE POLICY "Authenticated users can insert products"
ON products FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update products
CREATE POLICY "Authenticated users can update products"
ON products FOR UPDATE
TO authenticated
USING (true);

-- Policy: Allow authenticated users to delete products
CREATE POLICY "Authenticated users can delete products"
ON products FOR DELETE
TO authenticated
USING (true);

-- =============================================
-- 6. CREATE TRIGGER FOR UPDATED_AT
-- =============================================

CREATE OR REPLACE FUNCTION update_products_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_products_updated_at();

-- =============================================
-- 7. CREATE FUNCTION TO GET NEXT PRODUCT SERIAL
-- =============================================

CREATE OR REPLACE FUNCTION get_next_product_serial()
RETURNS TEXT AS $$
DECLARE
    next_number INTEGER;
    next_serial TEXT;
BEGIN
    -- Get the highest serial number
    SELECT COALESCE(
        MAX(CAST(SUBSTRING(product_serial FROM 3) AS INTEGER)),
        0
    ) + 1 INTO next_number
    FROM products
    WHERE product_serial ~ '^UR[0-9]+$';
    
    -- Format as UR0001, UR0002, etc.
    next_serial := 'UR' || LPAD(next_number::TEXT, 4, '0');
    
    RETURN next_serial;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 8. GRANT PERMISSIONS
-- =============================================

-- Grant usage on the sequence
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant permissions on the table
GRANT SELECT ON products TO anon;
GRANT ALL ON products TO authenticated;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION get_next_product_serial() TO authenticated;

-- =============================================
-- 9. CREATE VIEW FOR PRODUCT SUMMARY
-- =============================================

-- View to get product summary with unit count
CREATE OR REPLACE VIEW product_summary AS
SELECT 
    product_serial,
    product_name_en,
    product_name_ar,
    category_name_en,
    category_name_ar,
    tax_category_name_en,
    tax_category_name_ar,
    tax_percentage,
    COUNT(*) as unit_count,
    MIN(sale_price) as min_price,
    MAX(sale_price) as max_price,
    is_active,
    created_at,
    updated_at
FROM products
GROUP BY 
    product_serial,
    product_name_en,
    product_name_ar,
    category_name_en,
    category_name_ar,
    tax_category_name_en,
    tax_category_name_ar,
    tax_percentage,
    is_active,
    created_at,
    updated_at
ORDER BY created_at DESC;

GRANT SELECT ON product_summary TO authenticated;
GRANT SELECT ON product_summary TO anon;

-- =============================================
-- MIGRATION COMPLETE
-- =============================================

COMMENT ON TABLE products IS 'Products table storing each unit as a separate entry linked by product_serial';
COMMENT ON COLUMN products.product_serial IS 'Auto-generated product serial (e.g., UR0001) shared by all units';
COMMENT ON COLUMN products.product_name_en IS 'Product name in English';
COMMENT ON COLUMN products.product_name_ar IS 'Product name in Arabic';
COMMENT ON COLUMN products.category_name_en IS 'Category name in English (denormalized)';
COMMENT ON COLUMN products.category_name_ar IS 'Category name in Arabic (denormalized)';
COMMENT ON COLUMN products.tax_category_name_en IS 'Tax category name in English (denormalized)';
COMMENT ON COLUMN products.tax_category_name_ar IS 'Tax category name in Arabic (denormalized)';
COMMENT ON COLUMN products.tax_percentage IS 'Tax percentage for this product';
COMMENT ON COLUMN products.unit_name_en IS 'Unit name in English (e.g., Kilogram)';
COMMENT ON COLUMN products.unit_name_ar IS 'Unit name in Arabic';
COMMENT ON COLUMN products.unit_qty IS 'Unit quantity (e.g., 1, 2, 3)';
COMMENT ON COLUMN products.barcode IS 'Product barcode (unique per unit)';
COMMENT ON COLUMN products.sale_price IS 'Sale price (inclusive of tax)';
COMMENT ON COLUMN products.cost IS 'Cost price (inclusive of tax)';
COMMENT ON COLUMN products.profit IS 'Profit amount (excluding tax)';
COMMENT ON COLUMN products.profit_percentage IS 'Profit percentage';
COMMENT ON COLUMN products.current_stock IS 'Current stock quantity available';
COMMENT ON COLUMN products.minim_qty IS 'Minimum quantity';
COMMENT ON COLUMN products.minimum_qty_alert IS 'Minimum quantity alert threshold';
COMMENT ON COLUMN products.maximum_qty IS 'Maximum quantity';
COMMENT ON COLUMN products.image_url IS 'Product unit image URL';

-- =============================================
-- 10. INSERT SAMPLE PRODUCTS (3 per category)
-- =============================================

-- Get category and tax IDs for sample data
DO $$
DECLARE
    cat_fruits_veg UUID;
    cat_dairy UUID;
    cat_bakery UUID;
    tax_vat UUID;
    unit_kg UUID;
    unit_gram UUID;
    unit_liter UUID;
    unit_piece UUID;
BEGIN
    -- Get category IDs
    SELECT id INTO cat_fruits_veg FROM product_categories WHERE name_en = 'Fruits & Vegetables' LIMIT 1;
    SELECT id INTO cat_dairy FROM product_categories WHERE name_en = 'Dairy & Eggs' LIMIT 1;
    SELECT id INTO cat_bakery FROM product_categories WHERE name_en = 'Bakery & Bread' LIMIT 1;
    
    -- Get tax category ID
    SELECT id INTO tax_vat FROM tax_categories WHERE name_en = 'VAT' LIMIT 1;
    
    -- Get unit IDs
    SELECT id INTO unit_kg FROM product_units WHERE name_en = 'Kilogram' LIMIT 1;
    SELECT id INTO unit_gram FROM product_units WHERE name_en = 'Gram' LIMIT 1;
    SELECT id INTO unit_liter FROM product_units WHERE name_en = 'Liter' LIMIT 1;
    SELECT id INTO unit_piece FROM product_units WHERE name_en = 'Piece' LIMIT 1;
    
    -- Product 1: Fresh Apples (Fruits & Vegetables) - 3 units
    INSERT INTO products (
        product_serial, product_name_en, product_name_ar,
        category_id, category_name_en, category_name_ar,
        tax_category_id, tax_category_name_en, tax_category_name_ar, tax_percentage,
        unit_id, unit_name_en, unit_name_ar, unit_qty,
        barcode, sale_price, cost, profit, profit_percentage,
        current_stock, minim_qty, minimum_qty_alert, maximum_qty,
        image_url
    ) VALUES
    ('UR0001', 'Fresh Apples', 'تفاح طازج',
     cat_fruits_veg, 'Fruits & Vegetables', 'الفواكه والخضروات',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_kg, 'Kilogram', 'كيلوجرام', 1,
     '0401567010200', 10.00, 5.00, 4.35, 100.00,
     50, 2, 4, 8,
     'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=500'),
    
    ('UR0001', 'Fresh Apples', 'تفاح طازج',
     cat_fruits_veg, 'Fruits & Vegetables', 'الفواكه والخضروات',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_kg, 'Kilogram', 'كيلوجرام', 2,
     '0401567020200', 20.00, 10.00, 8.70, 100.00,
     30, 4, 8, 16,
     'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=500'),
    
    ('UR0001', 'Fresh Apples', 'تفاح طازج',
     cat_fruits_veg, 'Fruits & Vegetables', 'الفواكه والخضروات',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_kg, 'Kilogram', 'كيلوجرام', 5,
     '0401567050200', 45.00, 22.50, 19.57, 100.00,
     20, 10, 20, 40,
     'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=500'),
    
    -- Product 2: Organic Carrots (Fruits & Vegetables) - 2 units
    ('UR0002', 'Organic Carrots', 'جزر عضوي',
     cat_fruits_veg, 'Fruits & Vegetables', 'الفواكه والخضروات',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_kg, 'Kilogram', 'كيلوجرام', 1,
     '0401568010200', 8.00, 4.00, 3.48, 100.00,
     40, 2, 4, 8,
     'https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?w=500'),
    
    ('UR0002', 'Organic Carrots', 'جزر عضوي',
     cat_fruits_veg, 'Fruits & Vegetables', 'الفواكه والخضروات',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_gram, 'Gram', 'جرام', 500,
     '0401568500200', 4.50, 2.25, 1.96, 100.00,
     60, 1, 2, 4,
     'https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?w=500'),
    
    -- Product 3: Fresh Tomatoes (Fruits & Vegetables) - 2 units
    ('UR0003', 'Fresh Tomatoes', 'طماطم طازجة',
     cat_fruits_veg, 'Fruits & Vegetables', 'الفواكه والخضروات',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_kg, 'Kilogram', 'كيلوجرام', 1,
     '0401569010200', 6.00, 3.00, 2.61, 100.00,
     70, 2, 4, 8,
     'https://images.unsplash.com/photo-1546470427-e26264be0b1c?w=500'),
    
    ('UR0003', 'Fresh Tomatoes', 'طماطم طازجة',
     cat_fruits_veg, 'Fruits & Vegetables', 'الفواكه والخضروات',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_kg, 'Kilogram', 'كيلوجرام', 3,
     '0401569030200', 17.00, 8.50, 7.39, 100.00,
     35, 6, 12, 24,
     'https://images.unsplash.com/photo-1546470427-e26264be0b1c?w=500'),
    
    -- Product 4: Fresh Milk (Dairy & Eggs) - 3 units
    ('UR0004', 'Fresh Milk', 'حليب طازج',
     cat_dairy, 'Dairy & Eggs', 'الألبان والبيض',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_liter, 'Liter', 'لتر', 1,
     '0401570010300', 5.00, 3.00, 1.74, 66.67,
     100, 2, 4, 8,
     'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500'),
    
    ('UR0004', 'Fresh Milk', 'حليب طازج',
     cat_dairy, 'Dairy & Eggs', 'الألبان والبيض',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_liter, 'Liter', 'لتر', 2,
     '0401570020300', 9.50, 5.70, 3.30, 66.67,
     80, 4, 8, 16,
     'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500'),
    
    ('UR0004', 'Fresh Milk', 'حليب طازج',
     cat_dairy, 'Dairy & Eggs', 'الألبان والبيض',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_liter, 'Liter', 'لتر', 4,
     '0401570040300', 18.00, 10.80, 6.26, 66.67,
     50, 8, 16, 32,
     'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500'),
    
    -- Product 5: Yogurt (Dairy & Eggs) - 2 units
    ('UR0005', 'Plain Yogurt', 'لبن زبادي طبيعي',
     cat_dairy, 'Dairy & Eggs', 'الألبان والبيض',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_gram, 'Gram', 'جرام', 500,
     '0401571500300', 4.50, 2.70, 1.57, 66.67,
     90, 1, 2, 4,
     'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=500'),
    
    ('UR0005', 'Plain Yogurt', 'لبن زبادي طبيعي',
     cat_dairy, 'Dairy & Eggs', 'الألبان والبيض',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_kg, 'Kilogram', 'كيلوجرام', 1,
     '0401571010300', 8.50, 5.10, 2.96, 66.67,
     70, 2, 4, 8,
     'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=500'),
    
    -- Product 6: Eggs (Dairy & Eggs) - 3 units
    ('UR0006', 'Fresh Eggs', 'بيض طازج',
     cat_dairy, 'Dairy & Eggs', 'الألبان والبيض',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_piece, 'Piece', 'قطعة', 6,
     '0401572060300', 8.00, 5.00, 2.61, 60.00,
     200, 12, 24, 48,
     'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=500'),
    
    ('UR0006', 'Fresh Eggs', 'بيض طازج',
     cat_dairy, 'Dairy & Eggs', 'الألبان والبيض',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_piece, 'Piece', 'قطعة', 12,
     '0401572120300', 15.00, 9.40, 4.87, 59.57,
     150, 24, 48, 96,
     'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=500'),
    
    ('UR0006', 'Fresh Eggs', 'بيض طازج',
     cat_dairy, 'Dairy & Eggs', 'الألبان والبيض',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_piece, 'Piece', 'قطعة', 30,
     '0401572300300', 35.00, 22.00, 11.30, 59.09,
     80, 60, 120, 240,
     'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=500'),
    
    -- Product 7: White Bread (Bakery & Bread) - 2 units
    ('UR0007', 'White Bread', 'خبز أبيض',
     cat_bakery, 'Bakery & Bread', 'المخبوزات والخبز',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_piece, 'Piece', 'قطعة', 1,
     '0401573010400', 3.00, 1.50, 1.30, 100.00,
     300, 2, 4, 8,
     'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500'),
    
    ('UR0007', 'White Bread', 'خبز أبيض',
     cat_bakery, 'Bakery & Bread', 'المخبوزات والخبز',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_piece, 'Piece', 'قطعة', 6,
     '0401573060400', 16.00, 8.00, 6.96, 100.00,
     120, 12, 24, 48,
     'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500'),
    
    -- Product 8: Croissant (Bakery & Bread) - 2 units
    ('UR0008', 'Butter Croissant', 'كرواسون بالزبدة',
     cat_bakery, 'Bakery & Bread', 'المخبوزات والخبز',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_piece, 'Piece', 'قطعة', 1,
     '0401574010400', 4.00, 2.00, 1.74, 100.00,
     150, 2, 4, 8,
     'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=500'),
    
    ('UR0008', 'Butter Croissant', 'كرواسون بالزبدة',
     cat_bakery, 'Bakery & Bread', 'المخبوزات والخبز',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_piece, 'Piece', 'قطعة', 4,
     '0401574040400', 14.00, 7.00, 6.09, 100.00,
     80, 8, 16, 32,
     'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=500'),
    
    -- Product 9: Cake (Bakery & Bread) - 3 units
    ('UR0009', 'Chocolate Cake', 'كيك شوكولاتة',
     cat_bakery, 'Bakery & Bread', 'المخبوزات والخبز',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_gram, 'Gram', 'جرام', 500,
     '0401575500400', 25.00, 15.00, 8.70, 66.67,
     40, 1, 2, 4,
     'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=500'),
    
    ('UR0009', 'Chocolate Cake', 'كيك شوكولاتة',
     cat_bakery, 'Bakery & Bread', 'المخبوزات والخبز',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_kg, 'Kilogram', 'كيلوجرام', 1,
     '0401575010400', 45.00, 27.00, 15.65, 66.67,
     25, 2, 4, 8,
     'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=500'),
    
    ('UR0009', 'Chocolate Cake', 'كيك شوكولاتة',
     cat_bakery, 'Bakery & Bread', 'المخبوزات والخبز',
     tax_vat, 'VAT', 'ضريبة القيمة المضافة', 15.00,
     unit_kg, 'Kilogram', 'كيلوجرام', 2,
     '0401575020400', 85.00, 51.00, 29.57, 66.67,
     15, 4, 8, 16,
     'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=500');
    
END $$;
