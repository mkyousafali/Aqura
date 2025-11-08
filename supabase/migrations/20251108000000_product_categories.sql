-- =============================================
-- PRODUCT CATEGORIES SYSTEM
-- =============================================
-- Date: 2025-11-08
-- Description: Create product categories table with image support
-- and storage bucket for category thumbnails

-- =============================================
-- 1. CREATE STORAGE BUCKET FOR CATEGORY IMAGES
-- =============================================

-- Create public storage bucket for category thumbnails
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'category-images',
  'category-images',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- =============================================
-- 2. STORAGE POLICIES FOR CATEGORY IMAGES
-- =============================================

-- Policy: Allow public read access to category images
CREATE POLICY "Public read access for category images"
ON storage.objects FOR SELECT
USING (bucket_id = 'category-images');

-- Policy: Allow authenticated users to upload category images
CREATE POLICY "Authenticated users can upload category images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'category-images');

-- Policy: Allow authenticated users to update category images
CREATE POLICY "Authenticated users can update category images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'category-images');

-- Policy: Allow authenticated users to delete category images
CREATE POLICY "Authenticated users can delete category images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'category-images');

-- =============================================
-- 3. CREATE PRODUCT CATEGORIES TABLE
-- =============================================

CREATE TABLE IF NOT EXISTS product_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name_en TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    image_url TEXT, -- URL to category thumbnail image
    display_order INTEGER DEFAULT 0, -- For ordering categories
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    
    -- Constraints
    CONSTRAINT unique_category_name_en UNIQUE(name_en),
    CONSTRAINT unique_category_name_ar UNIQUE(name_ar)
);

-- =============================================
-- 4. CREATE INDEXES
-- =============================================

CREATE INDEX idx_product_categories_active ON product_categories(is_active);
CREATE INDEX idx_product_categories_order ON product_categories(display_order);
CREATE INDEX idx_product_categories_created_at ON product_categories(created_at);

-- =============================================
-- 5. ENABLE ROW LEVEL SECURITY
-- =============================================

ALTER TABLE product_categories ENABLE ROW LEVEL SECURITY;

-- Policy: Allow public read access to active categories
CREATE POLICY "Public read access to active categories"
ON product_categories FOR SELECT
USING (is_active = true);

-- Policy: Allow authenticated users to read all categories
CREATE POLICY "Authenticated users can read all categories"
ON product_categories FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert categories
CREATE POLICY "Authenticated users can insert categories"
ON product_categories FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update categories
CREATE POLICY "Authenticated users can update categories"
ON product_categories FOR UPDATE
TO authenticated
USING (true);

-- Policy: Allow authenticated users to delete categories
CREATE POLICY "Authenticated users can delete categories"
ON product_categories FOR DELETE
TO authenticated
USING (true);

-- =============================================
-- 6. CREATE TRIGGER FOR UPDATED_AT
-- =============================================

CREATE OR REPLACE FUNCTION update_product_categories_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER product_categories_updated_at
    BEFORE UPDATE ON product_categories
    FOR EACH ROW
    EXECUTE FUNCTION update_product_categories_updated_at();

-- =============================================
-- 7. INSERT DEFAULT CATEGORIES
-- =============================================

INSERT INTO product_categories (name_en, name_ar, display_order, is_active) VALUES
('Fruits & Vegetables', 'الفواكه والخضروات', 1, true),
('Dairy & Eggs', 'الألبان والبيض', 2, true),
('Bakery & Bread', 'المخبوزات والخبز', 3, true),
('Beverages', 'المشروبات', 4, true),
('Snacks & Confectionery', 'الوجبات الخفيفة والحلويات', 5, true),
('Frozen Foods', 'الأطعمة المجمدة', 6, true),
('Grains & Rice', 'الحبوب والأرز', 7, true),
('Spices & Condiments', 'التوابل والبهارات', 8, true),
('Cooking Oil & Ghee', 'الزيوت والسمن', 9, true),
('Canned & Jarred Foods', 'الأطعمة المعلبة والمحفوظة', 10, true),
('Breakfast & Cereals', 'الإفطار والحبوب', 11, true),
('Baby Care', 'رعاية الأطفال', 12, true),
('Personal Care', 'العناية الشخصية', 13, true),
('Household Cleaning', 'مستلزمات التنظيف', 14, true),
('Laundry', 'الغسيل والمنظفات', 15, true),
('Paper & Tissue', 'الورق والمناديل', 16, true),
('Pet Care', 'رعاية الحيوانات الأليفة', 17, true),
('Health & Wellness', 'الصحة والعافية', 18, true),
('School Supplies', 'مستلزمات مدرسية', 19, true),
('Ready Meals', 'وجبات جاهزة', 20, true)
ON CONFLICT (name_en) DO NOTHING;

-- =============================================
-- 8. GRANT PERMISSIONS
-- =============================================

-- Grant usage on the sequence
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant permissions on the table
GRANT SELECT ON product_categories TO anon;
GRANT ALL ON product_categories TO authenticated;

-- =============================================
-- MIGRATION COMPLETE
-- =============================================

COMMENT ON TABLE product_categories IS 'Product categories with image support for customer app';
COMMENT ON COLUMN product_categories.image_url IS 'URL to category thumbnail image stored in category-images bucket';
COMMENT ON COLUMN product_categories.display_order IS 'Order in which categories are displayed (lower number = higher priority)';
