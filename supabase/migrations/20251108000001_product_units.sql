-- =============================================
-- PRODUCT UNITS SYSTEM
-- =============================================
-- Date: 2025-11-08
-- Description: Create product_units table with common hypermarket base units

-- =============================================
-- 1. CREATE PRODUCT UNITS TABLE
-- =============================================

CREATE TABLE IF NOT EXISTS product_units (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name_en TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    
    -- Constraints
    CONSTRAINT unique_unit_name_en UNIQUE(name_en),
    CONSTRAINT unique_unit_name_ar UNIQUE(name_ar)
);

-- =============================================
-- 2. CREATE INDEXES
-- =============================================

CREATE INDEX idx_product_units_active ON product_units(is_active);
CREATE INDEX idx_product_units_created_at ON product_units(created_at);

-- =============================================
-- 3. ENABLE ROW LEVEL SECURITY
-- =============================================

ALTER TABLE product_units ENABLE ROW LEVEL SECURITY;

-- Policy: Allow public read access to active units
CREATE POLICY "Public read access to active units"
ON product_units FOR SELECT
USING (is_active = true);

-- Policy: Allow authenticated users to read all units
CREATE POLICY "Authenticated users can read all units"
ON product_units FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert units
CREATE POLICY "Authenticated users can insert units"
ON product_units FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update units
CREATE POLICY "Authenticated users can update units"
ON product_units FOR UPDATE
TO authenticated
USING (true);

-- Policy: Allow authenticated users to delete units
CREATE POLICY "Authenticated users can delete units"
ON product_units FOR DELETE
TO authenticated
USING (true);

-- =============================================
-- 4. CREATE TRIGGER FOR UPDATED_AT
-- =============================================

CREATE OR REPLACE FUNCTION update_product_units_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER product_units_updated_at
    BEFORE UPDATE ON product_units
    FOR EACH ROW
    EXECUTE FUNCTION update_product_units_updated_at();

-- =============================================
-- 5. INSERT DEFAULT UNITS (COMMON HYPERMARKET UNITS)
-- =============================================

INSERT INTO product_units (name_en, name_ar, is_active) VALUES
-- Weight Units
('Kilogram', 'كيلوجرام', true),
('Gram', 'جرام', true),
('Pound', 'رطل', true),
('Ounce', 'أونصة', true),

-- Volume Units
('Liter', 'لتر', true),
('Milliliter', 'مليلتر', true),
('Gallon', 'جالون', true),

-- Quantity Units
('Piece', 'قطعة', true),
('Pack', 'عبوة', true),
('Box', 'صندوق', true),
('Carton', 'كرتون', true),
('Bottle', 'زجاجة', true),
('Can', 'علبة', true),
('Jar', 'برطمان', true),
('Bag', 'كيس', true),
('Packet', 'باكيت', true),
('Bundle', 'حزمة', true),
('Roll', 'لفة', true),
('Tube', 'أنبوب', true),
('Tray', 'صينية', true),

-- Dozen
('Dozen', 'دزينة', true),
('Half Dozen', 'نصف دزينة', true)

ON CONFLICT (name_en) DO NOTHING;

-- =============================================
-- 6. GRANT PERMISSIONS
-- =============================================

-- Grant usage on the sequence
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant permissions on the table
GRANT SELECT ON product_units TO anon;
GRANT ALL ON product_units TO authenticated;

-- =============================================
-- MIGRATION COMPLETE
-- =============================================

COMMENT ON TABLE product_units IS 'Product base units used in hypermarket inventory and sales';
COMMENT ON COLUMN product_units.name_en IS 'Unit name in English';
COMMENT ON COLUMN product_units.name_ar IS 'Unit name in Arabic';
