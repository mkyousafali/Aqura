-- Create asset_main_categories table
-- Stores main asset categories (Land, Buildings, Refrigeration, etc.)

DROP TABLE IF EXISTS asset_sub_categories CASCADE;
DROP TABLE IF EXISTS asset_main_categories CASCADE;

CREATE TABLE asset_main_categories (
    id SERIAL PRIMARY KEY,
    group_code VARCHAR(20) NOT NULL UNIQUE,
    name_en VARCHAR(255) NOT NULL,
    name_ar VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(name_en)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_asset_main_categories_name_en ON asset_main_categories(name_en);
CREATE INDEX IF NOT EXISTS idx_asset_main_categories_group_code ON asset_main_categories(group_code);

-- Enable RLS
ALTER TABLE asset_main_categories ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Allow all access to asset_main_categories" ON asset_main_categories;

-- Permissive policy
CREATE POLICY "Allow all access to asset_main_categories"
    ON asset_main_categories
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Grant access to all roles
GRANT ALL ON asset_main_categories TO anon;
GRANT ALL ON asset_main_categories TO authenticated;
GRANT ALL ON asset_main_categories TO service_role;

-- Grant sequence access
GRANT USAGE, SELECT ON SEQUENCE asset_main_categories_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE asset_main_categories_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE asset_main_categories_id_seq TO service_role;

-- Insert main categories
INSERT INTO asset_main_categories (group_code, name_en, name_ar) VALUES
    ('PPE-LND', 'Land', 'أراضي'),
    ('PPE-BLD', 'Buildings', 'مباني'),
    ('PPE-LHI', 'Leasehold Improvements', 'تحسينات مستأجرة'),
    ('PPE-REF', 'Refrigeration', 'تبريد'),
    ('PPE-PLM', 'Plant & Machinery', 'آلات ومعدات'),
    ('PPE-FNF', 'Furniture & Fixtures', 'أثاث وتجهيزات'),
    ('PPE-SHL', 'Shelving', 'أرفف'),
    ('PPE-ITE', 'IT Equipment', 'معدات تقنية'),
    ('PPE-POS', 'POS Equipment', 'أجهزة نقاط البيع'),
    ('PPE-CCTV', 'Security', 'أمن'),
    ('PPE-SAF', 'Safety', 'سلامة'),
    ('PPE-WHE', 'Warehouse', 'مستودعات'),
    ('PPE-VEH', 'Vehicles', 'مركبات'),
    ('PPE-GEN', 'Power', 'طاقة'),
    ('PPE-AC', 'HVAC', 'تكييف'),
    ('PPE-OTH', 'Miscellaneous', 'متنوعات'),
    ('INT-SFT', 'Intangible', 'أصول غير ملموسة'),
    ('TMP-000', 'Temporary', 'مؤقت');
