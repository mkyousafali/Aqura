-- =============================================
-- TAX CATEGORIES SYSTEM
-- =============================================
-- Date: 2025-11-08
-- Description: Create tax_categories table with VAT as default

-- =============================================
-- 1. CREATE TAX CATEGORIES TABLE
-- =============================================

CREATE TABLE IF NOT EXISTS tax_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name_en TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    percentage NUMERIC(5, 2) NOT NULL CHECK (percentage >= 0 AND percentage <= 100),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    
    -- Constraints
    CONSTRAINT unique_tax_name_en UNIQUE(name_en),
    CONSTRAINT unique_tax_name_ar UNIQUE(name_ar)
);

-- =============================================
-- 2. CREATE INDEXES
-- =============================================

CREATE INDEX idx_tax_categories_active ON tax_categories(is_active);
CREATE INDEX idx_tax_categories_created_at ON tax_categories(created_at);

-- =============================================
-- 3. ENABLE ROW LEVEL SECURITY
-- =============================================

ALTER TABLE tax_categories ENABLE ROW LEVEL SECURITY;

-- Policy: Allow public read access to active taxes
CREATE POLICY "Public read access to active taxes"
ON tax_categories FOR SELECT
USING (is_active = true);

-- Policy: Allow authenticated users to read all taxes
CREATE POLICY "Authenticated users can read all taxes"
ON tax_categories FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert taxes
CREATE POLICY "Authenticated users can insert taxes"
ON tax_categories FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update taxes
CREATE POLICY "Authenticated users can update taxes"
ON tax_categories FOR UPDATE
TO authenticated
USING (true);

-- Policy: Allow authenticated users to delete taxes
CREATE POLICY "Authenticated users can delete taxes"
ON tax_categories FOR DELETE
TO authenticated
USING (true);

-- =============================================
-- 4. CREATE TRIGGER FOR UPDATED_AT
-- =============================================

CREATE OR REPLACE FUNCTION update_tax_categories_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tax_categories_updated_at
    BEFORE UPDATE ON tax_categories
    FOR EACH ROW
    EXECUTE FUNCTION update_tax_categories_updated_at();

-- =============================================
-- 5. INSERT DEFAULT TAX CATEGORY (VAT 15%)
-- =============================================

INSERT INTO tax_categories (name_en, name_ar, percentage, is_active) VALUES
('VAT', 'ضريبة القيمة المضافة', 15.00, true)
ON CONFLICT (name_en) DO NOTHING;

-- =============================================
-- 6. GRANT PERMISSIONS
-- =============================================

-- Grant usage on the sequence
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant permissions on the table
GRANT SELECT ON tax_categories TO anon;
GRANT ALL ON tax_categories TO authenticated;

-- =============================================
-- MIGRATION COMPLETE
-- =============================================

COMMENT ON TABLE tax_categories IS 'Tax categories for product pricing in the hypermarket system';
COMMENT ON COLUMN tax_categories.name_en IS 'Tax category name in English';
COMMENT ON COLUMN tax_categories.name_ar IS 'Tax category name in Arabic';
COMMENT ON COLUMN tax_categories.percentage IS 'Tax percentage (0-100)';
