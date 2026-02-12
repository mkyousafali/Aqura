-- Create asset_sub_categories table
-- Stores individual asset types with depreciation rates, linked to main categories

CREATE TABLE asset_sub_categories (
    id SERIAL PRIMARY KEY,
    category_id INTEGER NOT NULL REFERENCES asset_main_categories(id) ON DELETE CASCADE,
    group_code VARCHAR(20) NOT NULL,
    name_en VARCHAR(255) NOT NULL,
    name_ar VARCHAR(255) NOT NULL,
    useful_life_years VARCHAR(20),
    annual_depreciation_pct DECIMAL(8,4) DEFAULT 0,
    monthly_depreciation_pct DECIMAL(8,4) DEFAULT 0,
    residual_pct VARCHAR(20) DEFAULT '0%',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(group_code, name_en)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_asset_sub_categories_category_id ON asset_sub_categories(category_id);
CREATE INDEX IF NOT EXISTS idx_asset_sub_categories_group_code ON asset_sub_categories(group_code);

-- Enable RLS
ALTER TABLE asset_sub_categories ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Allow all access to asset_sub_categories" ON asset_sub_categories;

-- Permissive policy
CREATE POLICY "Allow all access to asset_sub_categories"
    ON asset_sub_categories
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Grant access to all roles
GRANT ALL ON asset_sub_categories TO anon;
GRANT ALL ON asset_sub_categories TO authenticated;
GRANT ALL ON asset_sub_categories TO service_role;

-- Grant sequence access
GRANT USAGE, SELECT ON SEQUENCE asset_sub_categories_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE asset_sub_categories_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE asset_sub_categories_id_seq TO service_role;

-- ============================================================
-- Insert asset items (referencing category IDs by subquery)
-- ============================================================

-- Land
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Land'), 'PPE-LND', 'Freehold land', 'أرض ملك حر', '∞', 0.0000, 0.0000, '—'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Land'), 'PPE-LND', 'Land improvements (parking paving)', 'تحسينات أرضية (رصف مواقف)', '15', 6.6700, 0.5558, '5%');

-- Buildings
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Buildings'), 'PPE-BLD', 'Store building', 'مبنى متجر', '30', 3.3300, 0.2775, '5–10%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Buildings'), 'PPE-BLD', 'Warehouse building', 'مبنى مستودع', '30', 3.3300, 0.2775, '5–10%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Buildings'), 'PPE-BLD', 'Office building', 'مبنى مكتبي', '25', 4.0000, 0.3333, '5–10%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Buildings'), 'PPE-BLD', 'Mezzanine structure', 'هيكل ميزانين', '20', 5.0000, 0.4167, '5%');

-- Leasehold Improvements
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Leasehold Improvements'), 'PPE-LHI', 'Interior fit-out', 'تجهيزات داخلية', '10', 10.0000, 0.8333, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Leasehold Improvements'), 'PPE-LHI', 'Flooring', 'أرضيات', '8', 12.5000, 1.0417, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Leasehold Improvements'), 'PPE-LHI', 'Ceiling works', 'أعمال أسقف', '8', 12.5000, 1.0417, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Leasehold Improvements'), 'PPE-LHI', 'Glass partitions', 'حواجز زجاجية', '8', 12.5000, 1.0417, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Leasehold Improvements'), 'PPE-LHI', 'Electrical installation', 'تمديدات كهربائية', '10', 10.0000, 0.8333, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Leasehold Improvements'), 'PPE-LHI', 'Plumbing installation', 'تمديدات سباكة', '10', 10.0000, 0.8333, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Leasehold Improvements'), 'PPE-LHI', 'Fixed signage', 'لافتات ثابتة', '5', 20.0000, 1.6667, '0%');

-- Refrigeration
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Refrigeration'), 'PPE-REF', 'Upright chillers', 'ثلاجات عمودية', '8', 12.5000, 1.0417, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Refrigeration'), 'PPE-REF', 'Island freezers', 'فريزرات جزيرة', '8', 12.5000, 1.0417, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Refrigeration'), 'PPE-REF', 'Walk-in cold room', 'غرفة تبريد', '10', 10.0000, 0.8333, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Refrigeration'), 'PPE-REF', 'Ice cream freezer', 'فريزر آيس كريم', '7', 14.3000, 1.1917, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Refrigeration'), 'PPE-REF', 'Refrigeration compressors', 'ضواغط تبريد', '8', 12.5000, 1.0417, '5%');

-- Plant & Machinery
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Plant & Machinery'), 'PPE-PLM', 'Bakery oven', 'فرن مخبز', '10', 10.0000, 0.8333, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Plant & Machinery'), 'PPE-PLM', 'Dough mixer', 'عجانة', '8', 12.5000, 1.0417, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Plant & Machinery'), 'PPE-PLM', 'Proofing cabinet', 'خزانة تخمير', '8', 12.5000, 1.0417, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Plant & Machinery'), 'PPE-PLM', 'Meat cutting machine', 'آلة تقطيع لحوم', '8', 12.5000, 1.0417, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Plant & Machinery'), 'PPE-PLM', 'Slicer', 'آلة تقطيع شرائح', '6', 16.6700, 1.3892, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Plant & Machinery'), 'PPE-PLM', 'Vegetable cutter', 'آلة تقطيع خضروات', '6', 16.6700, 1.3892, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Plant & Machinery'), 'PPE-PLM', 'Coffee machine (commercial)', 'آلة قهوة (تجارية)', '5', 20.0000, 1.6667, '5%');

-- Furniture & Fixtures
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Furniture & Fixtures'), 'PPE-FNF', 'Checkout counter', 'كاونتر محاسبة', '5', 20.0000, 1.6667, '0–5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Furniture & Fixtures'), 'PPE-FNF', 'Office desks', 'مكاتب', '5', 20.0000, 1.6667, '0–5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Furniture & Fixtures'), 'PPE-FNF', 'Office chairs', 'كراسي مكتبية', '5', 20.0000, 1.6667, '0–5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Furniture & Fixtures'), 'PPE-FNF', 'Meeting table', 'طاولة اجتماعات', '5', 20.0000, 1.6667, '0–5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Furniture & Fixtures'), 'PPE-FNF', 'Staff lockers', 'خزائن موظفين', '7', 14.3000, 1.1917, '5%');

-- Shelving
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Shelving'), 'PPE-SHL', 'Gondola shelving', 'أرفف جندول', '7', 14.3000, 1.1917, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Shelving'), 'PPE-SHL', 'Wall shelving', 'أرفف حائطية', '7', 14.3000, 1.1917, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Shelving'), 'PPE-SHL', 'End-cap displays', 'عروض نهاية الرف', '6', 16.6700, 1.3892, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Shelving'), 'PPE-SHL', 'Promotional racks', 'حوامل ترويجية', '5', 20.0000, 1.6667, '5%');

-- IT Equipment
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'IT Equipment'), 'PPE-ITE', 'Desktop computers', 'أجهزة كمبيوتر مكتبية', '3', 33.3300, 2.7775, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'IT Equipment'), 'PPE-ITE', 'Laptops', 'أجهزة محمولة', '3', 33.3300, 2.7775, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'IT Equipment'), 'PPE-ITE', 'Servers', 'خوادم', '4', 25.0000, 2.0833, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'IT Equipment'), 'PPE-ITE', 'Network switches', 'محولات شبكة', '4', 25.0000, 2.0833, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'IT Equipment'), 'PPE-ITE', 'Routers', 'موجهات شبكة', '4', 25.0000, 2.0833, '0%');

-- POS Equipment
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'POS Equipment'), 'PPE-POS', 'POS terminals', 'أجهزة نقاط البيع', '4', 25.0000, 2.0833, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'POS Equipment'), 'PPE-POS', 'Barcode scanners', 'ماسحات باركود', '4', 25.0000, 2.0833, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'POS Equipment'), 'PPE-POS', 'Receipt printers', 'طابعات إيصالات', '4', 25.0000, 2.0833, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'POS Equipment'), 'PPE-POS', 'Cash drawers', 'أدراج نقدية', '5', 20.0000, 1.6667, '0%');

-- Security
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Security'), 'PPE-CCTV', 'CCTV cameras', 'كاميرات مراقبة', '5', 20.0000, 1.6667, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Security'), 'PPE-CCTV', 'DVR/NVR', 'أجهزة تسجيل رقمية', '5', 20.0000, 1.6667, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Security'), 'PPE-CCTV', 'Access control system', 'نظام التحكم بالدخول', '5', 20.0000, 1.6667, '0%');

-- Safety
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Safety'), 'PPE-SAF', 'Fire alarm system', 'نظام إنذار حريق', '7', 14.3000, 1.1917, '0–5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Safety'), 'PPE-SAF', 'Fire extinguishers', 'طفايات حريق', '5', 20.0000, 1.6667, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Safety'), 'PPE-SAF', 'Emergency lighting', 'إضاءة طوارئ', '7', 14.3000, 1.1917, '0%');

-- Warehouse
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Warehouse'), 'PPE-WHE', 'Pallet racks', 'رفوف بالتات', '8', 12.5000, 1.0417, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Warehouse'), 'PPE-WHE', 'Conveyor system', 'نظام سير ناقل', '8', 12.5000, 1.0417, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Warehouse'), 'PPE-FLT', 'Electric forklift', 'رافعة شوكية كهربائية', '6', 16.6700, 1.3892, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Warehouse'), 'PPE-FLT', 'Manual pallet jack', 'جاك بالت يدوي', '5', 20.0000, 1.6667, '0%');

-- Vehicles
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Vehicles'), 'PPE-VEH', 'Delivery van', 'فان توصيل', '5', 20.0000, 1.6667, '10%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Vehicles'), 'PPE-VEH', 'Pickup truck', 'شاحنة بيك أب', '5', 20.0000, 1.6667, '10%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Vehicles'), 'PPE-RTR', 'Refrigerated truck', 'شاحنة مبردة', '6', 16.6700, 1.3892, '10%');

-- Power
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Power'), 'PPE-GEN', 'Generator', 'مولد كهربائي', '10', 10.0000, 0.8333, '5%');

-- HVAC
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'HVAC'), 'PPE-AC', 'Central AC', 'تكييف مركزي', '8', 12.5000, 1.0417, '5%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'HVAC'), 'PPE-AC', 'Split AC', 'تكييف سبليت', '6', 16.6700, 1.3892, '5%');

-- Miscellaneous
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Miscellaneous'), 'PPE-OTH', 'Water dispenser', 'برادة ماء', '5', 20.0000, 1.6667, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Miscellaneous'), 'PPE-OTH', 'Time attendance system', 'نظام حضور وانصراف', '5', 20.0000, 1.6667, '0%');

-- Intangible
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Intangible'), 'INT-SFT', 'ERP system', 'نظام تخطيط موارد', '5', 20.0000, 1.6667, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Intangible'), 'INT-SFT', 'POS software', 'برنامج نقاط البيع', '5', 20.0000, 1.6667, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Intangible'), 'INT-SFT', 'Mobile app', 'تطبيق جوال', '5', 20.0000, 1.6667, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Intangible'), 'INT-SFT', 'Loyalty platform', 'منصة ولاء', '5', 20.0000, 1.6667, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Intangible'), 'INT-LIC', 'Trade license', 'رخصة تجارية', 'Per term', 0.0000, 0.0000, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Intangible'), 'INT-DOM', 'Domain name (finite)', 'اسم نطاق (محدد)', '3', 33.3300, 2.7775, '0%'),
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Intangible'), 'INT-BRD', 'Brand / Trademark (Indefinite)', 'علامة تجارية (غير محددة)', 'Indefinite', 0.0000, 0.0000, '—');

-- Temporary (placeholder for imported assets)
INSERT INTO asset_sub_categories (category_id, group_code, name_en, name_ar, useful_life_years, annual_depreciation_pct, monthly_depreciation_pct, residual_pct) VALUES
    ((SELECT id FROM asset_main_categories WHERE name_en = 'Temporary'), 'TMP-000', 'Uncategorized', 'غير مصنف', '—', 0.0000, 0.0000, '0%');
