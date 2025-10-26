-- Migration: Create Expense Category Tables
-- Description: Create parent and sub expense category tables with bilingual support

-- Create parent expense categories table
CREATE TABLE IF NOT EXISTS expense_parent_categories (
    id BIGSERIAL PRIMARY KEY,
    name_en TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create sub expense categories table
CREATE TABLE IF NOT EXISTS expense_sub_categories (
    id BIGSERIAL PRIMARY KEY,
    parent_category_id BIGINT NOT NULL REFERENCES expense_parent_categories(id) ON DELETE CASCADE,
    name_en TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_expense_sub_categories_parent ON expense_sub_categories(parent_category_id);

-- Insert Parent Categories
INSERT INTO expense_parent_categories (name_en, name_ar) VALUES
('Employee Benefits', 'مزايا الموظفين'),
('Administrative & General Expenses', 'المصروفات الإدارية والعامة'),
('Purchasing & Procurement', 'المشتريات والتوريد'),
('Selling & Distribution', 'المبيعات والتوزيع'),
('Marketing & Customer Engagement', 'التسويق وتفاعل العملاء'),
('IT & Systems', 'تقنية المعلومات والأنظمة'),
('Finance & Banking', 'التمويل والبنوك'),
('Utilities & Energy', 'المرافق والطاقة'),
('Other Operating Expenses', 'مصروفات تشغيلية أخرى'),
('Tax & Compliance', 'الضرائب والالتزام');

-- Insert Sub Categories for Employee Benefits
INSERT INTO expense_sub_categories (parent_category_id, name_en, name_ar)
SELECT id, 'Salaries & Wages', 'الرواتب والأجور' FROM expense_parent_categories WHERE name_en = 'Employee Benefits'
UNION ALL
SELECT id, 'Overtime & Allowances', 'الساعات الإضافية والبدلات' FROM expense_parent_categories WHERE name_en = 'Employee Benefits'
UNION ALL
SELECT id, 'Bonuses & Incentives', 'المكافآت والحوافز' FROM expense_parent_categories WHERE name_en = 'Employee Benefits'
UNION ALL
SELECT id, 'End of Service Benefits', 'مكافأة نهاية الخدمة' FROM expense_parent_categories WHERE name_en = 'Employee Benefits'
UNION ALL
SELECT id, 'Social Insurance (GOSI)', 'التأمينات الاجتماعية' FROM expense_parent_categories WHERE name_en = 'Employee Benefits'
UNION ALL
SELECT id, 'Medical Insurance', 'التأمين الطبي' FROM expense_parent_categories WHERE name_en = 'Employee Benefits'
UNION ALL
SELECT id, 'Training & Development', 'التدريب والتطوير' FROM expense_parent_categories WHERE name_en = 'Employee Benefits'
UNION ALL
SELECT id, 'Recruitment & Onboarding', 'التوظيف والانضمام' FROM expense_parent_categories WHERE name_en = 'Employee Benefits'
UNION ALL
SELECT id, 'Staff Accommodation', 'سكن الموظفين' FROM expense_parent_categories WHERE name_en = 'Employee Benefits'
UNION ALL
SELECT id, 'Staff Meals', 'وجبات الموظفين' FROM expense_parent_categories WHERE name_en = 'Employee Benefits'
UNION ALL
SELECT id, 'Staff Transport', 'نقل الموظفين' FROM expense_parent_categories WHERE name_en = 'Employee Benefits'
UNION ALL
SELECT id, 'Uniforms & Safety Gear', 'الزي الرسمي ومعدات السلامة' FROM expense_parent_categories WHERE name_en = 'Employee Benefits'
UNION ALL
SELECT id, 'Employee Rewards & Events', 'جوائز وفعاليات الموظفين' FROM expense_parent_categories WHERE name_en = 'Employee Benefits'
UNION ALL
SELECT id, 'Employee Welfare Activities', 'أنشطة رفاهية الموظفين' FROM expense_parent_categories WHERE name_en = 'Employee Benefits'
UNION ALL
SELECT id, 'Payroll & HR System Subscription', 'اشتراكات أنظمة الموارد البشرية والرواتب' FROM expense_parent_categories WHERE name_en = 'Employee Benefits';

-- Insert Sub Categories for Administrative & General Expenses
INSERT INTO expense_sub_categories (parent_category_id, name_en, name_ar)
SELECT id, 'Rent & Lease', 'الإيجارات والعقود' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Electricity', 'الكهرباء' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Water', 'المياه' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Internet & Broadband', 'الإنترنت' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Telephone & Mobile Services', 'خدمات الهاتف' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Cleaning & Sanitation', 'النظافة والتعقيم' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Pest Control', 'مكافحة الحشرات' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Security & Surveillance', 'الأمن والمراقبة' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Maintenance & Repairs', 'الصيانة والإصلاحات' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Office Supplies & Stationery', 'القرطاسية ومستلزمات المكاتب' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Printing & Photocopying', 'الطباعة والنسخ' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Courier & Postal Services', 'البريد السريع والعادي' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Travel & Accommodation', 'السفر والإقامة' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Refreshments & Hospitality', 'الضيافة والمرطبات' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Property Insurance', 'التأمين على الممتلكات' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'General Liability Insurance', 'التأمين ضد المسؤولية' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Vehicle Insurance', 'تأمين المركبات' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Professional Fees – Audit', 'أتعاب المراجعة' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Professional Fees – Legal', 'أتعاب الاستشارات القانونية' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Licenses & Renewals', 'التراخيص والتجديدات' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Municipality & Government Fees', 'الرسوم الحكومية والبلدية' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Fines & Penalties', 'الغرامات والعقوبات' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Donations & CSR Projects', 'التبرعات والمسؤولية الاجتماعية' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Depreciation – Buildings', 'إهلاك المباني' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Depreciation – Equipment', 'إهلاك المعدات' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses'
UNION ALL
SELECT id, 'Amortisation – Software', 'إهلاك البرمجيات' FROM expense_parent_categories WHERE name_en = 'Administrative & General Expenses';

-- Insert Sub Categories for Purchasing & Procurement
INSERT INTO expense_sub_categories (parent_category_id, name_en, name_ar)
SELECT id, 'Procurement Salaries & Wages', 'رواتب وأجور قسم المشتريات' FROM expense_parent_categories WHERE name_en = 'Purchasing & Procurement'
UNION ALL
SELECT id, 'Vendor Management', 'إدارة الموردين' FROM expense_parent_categories WHERE name_en = 'Purchasing & Procurement'
UNION ALL
SELECT id, 'Import Documentation', 'مستندات ووثائق الاستيراد' FROM expense_parent_categories WHERE name_en = 'Purchasing & Procurement'
UNION ALL
SELECT id, 'Freight Negotiation Fees', 'رسوم التفاوض على الشحن' FROM expense_parent_categories WHERE name_en = 'Purchasing & Procurement'
UNION ALL
SELECT id, 'Customs Coordination Charges', 'مصاريف التنسيق الجمركي' FROM expense_parent_categories WHERE name_en = 'Purchasing & Procurement'
UNION ALL
SELECT id, 'Purchase Order Processing', 'معالجة أوامر الشراء' FROM expense_parent_categories WHERE name_en = 'Purchasing & Procurement'
UNION ALL
SELECT id, 'Broker & Agent Fees', 'عمولات الوسطاء والوكلاء' FROM expense_parent_categories WHERE name_en = 'Purchasing & Procurement'
UNION ALL
SELECT id, 'Vendor Evaluation & Audit', 'تقييم وتدقيق الموردين' FROM expense_parent_categories WHERE name_en = 'Purchasing & Procurement'
UNION ALL
SELECT id, 'Quality Inspection & Testing', 'الفحص وضمان الجودة' FROM expense_parent_categories WHERE name_en = 'Purchasing & Procurement'
UNION ALL
SELECT id, 'Procurement Software Subscription', 'اشتراك نظام المشتريات' FROM expense_parent_categories WHERE name_en = 'Purchasing & Procurement';

-- Insert Sub Categories for Selling & Distribution
INSERT INTO expense_sub_categories (parent_category_id, name_en, name_ar)
SELECT id, 'Store Rent', 'إيجار المتجر' FROM expense_parent_categories WHERE name_en = 'Selling & Distribution'
UNION ALL
SELECT id, 'Utilities – Electricity & Water', 'الكهرباء والمياه' FROM expense_parent_categories WHERE name_en = 'Selling & Distribution'
UNION ALL
SELECT id, 'Store Maintenance', 'صيانة المتجر' FROM expense_parent_categories WHERE name_en = 'Selling & Distribution'
UNION ALL
SELECT id, 'Cleaning & Janitorial', 'خدمات التنظيف' FROM expense_parent_categories WHERE name_en = 'Selling & Distribution'
UNION ALL
SELECT id, 'Refrigeration & AC Maintenance', 'صيانة التبريد والتكييف' FROM expense_parent_categories WHERE name_en = 'Selling & Distribution'
UNION ALL
SELECT id, 'Store Supplies & Consumables', 'مستلزمات المتجر' FROM expense_parent_categories WHERE name_en = 'Selling & Distribution'
UNION ALL
SELECT id, 'POS Consumables', 'مستلزمات نقاط البيع' FROM expense_parent_categories WHERE name_en = 'Selling & Distribution'
UNION ALL
SELECT id, 'Advertising & Promotions', 'الإعلانات والعروض' FROM expense_parent_categories WHERE name_en = 'Selling & Distribution'
UNION ALL
SELECT id, 'Flyers & Displays', 'المنشورات واللافتات' FROM expense_parent_categories WHERE name_en = 'Selling & Distribution'
UNION ALL
SELECT id, 'Store Decoration & Events', 'ديكور وفعاليات المتجر' FROM expense_parent_categories WHERE name_en = 'Selling & Distribution'
UNION ALL
SELECT id, 'Security / Loss Prevention', 'الأمن ومنع الفقد' FROM expense_parent_categories WHERE name_en = 'Selling & Distribution'
UNION ALL
SELECT id, 'Delivery Fuel & Repairs', 'وقود وصيانة سيارات التوصيل' FROM expense_parent_categories WHERE name_en = 'Selling & Distribution'
UNION ALL
SELECT id, 'Delivery Packaging Materials', 'مواد تغليف التوصيل' FROM expense_parent_categories WHERE name_en = 'Selling & Distribution'
UNION ALL
SELECT id, 'Courier & Delivery Fees', 'رسوم التوصيل' FROM expense_parent_categories WHERE name_en = 'Selling & Distribution'
UNION ALL
SELECT id, 'GPS & Fleet Tracking', 'تتبع المركبات' FROM expense_parent_categories WHERE name_en = 'Selling & Distribution';

-- Insert Sub Categories for Marketing & Customer Engagement
INSERT INTO expense_sub_categories (parent_category_id, name_en, name_ar)
SELECT id, 'Advertising – Print', 'إعلانات مطبوعة' FROM expense_parent_categories WHERE name_en = 'Marketing & Customer Engagement'
UNION ALL
SELECT id, 'Advertising – Digital', 'إعلانات رقمية' FROM expense_parent_categories WHERE name_en = 'Marketing & Customer Engagement'
UNION ALL
SELECT id, 'Outdoor & Billboard Ads', 'إعلانات خارجية' FROM expense_parent_categories WHERE name_en = 'Marketing & Customer Engagement'
UNION ALL
SELECT id, 'Radio & TV Ads', 'إعلانات إذاعية وتلفزيونية' FROM expense_parent_categories WHERE name_en = 'Marketing & Customer Engagement'
UNION ALL
SELECT id, 'Sponsorships & Events', 'الرعايات والفعاليات' FROM expense_parent_categories WHERE name_en = 'Marketing & Customer Engagement'
UNION ALL
SELECT id, 'Influencer Campaigns', 'حملات المؤثرين' FROM expense_parent_categories WHERE name_en = 'Marketing & Customer Engagement'
UNION ALL
SELECT id, 'Social Media Management', 'إدارة وسائل التواصل الاجتماعي' FROM expense_parent_categories WHERE name_en = 'Marketing & Customer Engagement'
UNION ALL
SELECT id, 'Branding & Design', 'العلامة التجارية والتصميم' FROM expense_parent_categories WHERE name_en = 'Marketing & Customer Engagement'
UNION ALL
SELECT id, 'Photography & Video Production', 'التصوير وإنتاج الفيديو' FROM expense_parent_categories WHERE name_en = 'Marketing & Customer Engagement'
UNION ALL
SELECT id, 'Loyalty Program Subscription', 'اشتراك نظام الولاء' FROM expense_parent_categories WHERE name_en = 'Marketing & Customer Engagement'
UNION ALL
SELECT id, 'Loyalty Points Redemption', 'استبدال نقاط الولاء' FROM expense_parent_categories WHERE name_en = 'Marketing & Customer Engagement'
UNION ALL
SELECT id, 'Gift Voucher & Coupon Costs', 'كوبونات وهدايا العملاء' FROM expense_parent_categories WHERE name_en = 'Marketing & Customer Engagement'
UNION ALL
SELECT id, 'Campaign Management Tools', 'أدوات إدارة الحملات' FROM expense_parent_categories WHERE name_en = 'Marketing & Customer Engagement'
UNION ALL
SELECT id, 'Customer Messaging Fees', 'رسوم أنظمة الرسائل للعملاء' FROM expense_parent_categories WHERE name_en = 'Marketing & Customer Engagement'
UNION ALL
SELECT id, 'WhatsApp & SMS Campaigns', 'حملات واتساب والرسائل القصيرة' FROM expense_parent_categories WHERE name_en = 'Marketing & Customer Engagement'
UNION ALL
SELECT id, 'Market Research & Surveys', 'أبحاث السوق والاستبيانات' FROM expense_parent_categories WHERE name_en = 'Marketing & Customer Engagement';

-- Insert Sub Categories for IT & Systems
INSERT INTO expense_sub_categories (parent_category_id, name_en, name_ar)
SELECT id, 'ERP License', 'ترخيص نظام إدارة الموارد' FROM expense_parent_categories WHERE name_en = 'IT & Systems'
UNION ALL
SELECT id, 'POS Software License', 'ترخيص نظام نقاط البيع' FROM expense_parent_categories WHERE name_en = 'IT & Systems'
UNION ALL
SELECT id, 'CRM System', 'نظام إدارة العملاء' FROM expense_parent_categories WHERE name_en = 'IT & Systems'
UNION ALL
SELECT id, 'Cloud Hosting', 'استضافة سحابية' FROM expense_parent_categories WHERE name_en = 'IT & Systems'
UNION ALL
SELECT id, 'Website & App Maintenance', 'صيانة المواقع والتطبيقات' FROM expense_parent_categories WHERE name_en = 'IT & Systems'
UNION ALL
SELECT id, 'Domain Renewal & SSL', 'تجديد النطاق وشهادات الأمان' FROM expense_parent_categories WHERE name_en = 'IT & Systems'
UNION ALL
SELECT id, 'Data Backup & Storage', 'النسخ الاحتياطي والتخزين' FROM expense_parent_categories WHERE name_en = 'IT & Systems'
UNION ALL
SELECT id, 'Internet Services', 'خدمات الإنترنت' FROM expense_parent_categories WHERE name_en = 'IT & Systems'
UNION ALL
SELECT id, 'IT Support & Maintenance', 'الدعم الفني والصيانة' FROM expense_parent_categories WHERE name_en = 'IT & Systems'
UNION ALL
SELECT id, 'Cybersecurity & Antivirus', 'الأمن السيبراني ومضاد الفيروسات' FROM expense_parent_categories WHERE name_en = 'IT & Systems'
UNION ALL
SELECT id, 'IT Consultancy', 'استشارات تقنية' FROM expense_parent_categories WHERE name_en = 'IT & Systems';

-- Insert Sub Categories for Finance & Banking
INSERT INTO expense_sub_categories (parent_category_id, name_en, name_ar)
SELECT id, 'Bank Charges', 'رسوم الخدمات البنكية' FROM expense_parent_categories WHERE name_en = 'Finance & Banking'
UNION ALL
SELECT id, 'POS Transaction Fees', 'رسوم معاملات نقاط البيع' FROM expense_parent_categories WHERE name_en = 'Finance & Banking'
UNION ALL
SELECT id, 'Credit Card Commission', 'عمولة بطاقات الائتمان' FROM expense_parent_categories WHERE name_en = 'Finance & Banking'
UNION ALL
SELECT id, 'Loan Interest', 'فوائد القروض' FROM expense_parent_categories WHERE name_en = 'Finance & Banking'
UNION ALL
SELECT id, 'Lease Interest', 'فوائد الإيجار' FROM expense_parent_categories WHERE name_en = 'Finance & Banking'
UNION ALL
SELECT id, 'Overdraft Interest', 'فوائد السحب على المكشوف' FROM expense_parent_categories WHERE name_en = 'Finance & Banking'
UNION ALL
SELECT id, 'Letter of Credit Fees', 'رسوم خطابات الاعتماد' FROM expense_parent_categories WHERE name_en = 'Finance & Banking'
UNION ALL
SELECT id, 'Foreign Exchange Differences', 'فروقات أسعار الصرف' FROM expense_parent_categories WHERE name_en = 'Finance & Banking'
UNION ALL
SELECT id, 'Bank Transfer Fees', 'رسوم التحويل البنكي' FROM expense_parent_categories WHERE name_en = 'Finance & Banking';

-- Insert Sub Categories for Utilities & Energy
INSERT INTO expense_sub_categories (parent_category_id, name_en, name_ar)
SELECT id, 'Electricity', 'الكهرباء' FROM expense_parent_categories WHERE name_en = 'Utilities & Energy'
UNION ALL
SELECT id, 'Water', 'المياه' FROM expense_parent_categories WHERE name_en = 'Utilities & Energy'
UNION ALL
SELECT id, 'Generator Fuel & Maintenance', 'وقود وصيانة المولدات' FROM expense_parent_categories WHERE name_en = 'Utilities & Energy'
UNION ALL
SELECT id, 'Gas & Energy Supplies', 'الغاز والطاقة' FROM expense_parent_categories WHERE name_en = 'Utilities & Energy'
UNION ALL
SELECT id, 'Waste Disposal', 'التخلص من النفايات' FROM expense_parent_categories WHERE name_en = 'Utilities & Energy'
UNION ALL
SELECT id, 'Sewage & Drainage', 'الصرف الصحي' FROM expense_parent_categories WHERE name_en = 'Utilities & Energy'
UNION ALL
SELECT id, 'Solar System Maintenance', 'صيانة الطاقة الشمسية' FROM expense_parent_categories WHERE name_en = 'Utilities & Energy';

-- Insert Sub Categories for Other Operating Expenses
INSERT INTO expense_sub_categories (parent_category_id, name_en, name_ar)
SELECT id, 'Miscellaneous Expenses', 'مصروفات متنوعة' FROM expense_parent_categories WHERE name_en = 'Other Operating Expenses'
UNION ALL
SELECT id, 'Temporary Labour', 'عمالة مؤقتة' FROM expense_parent_categories WHERE name_en = 'Other Operating Expenses'
UNION ALL
SELECT id, 'Meetings & Refreshments', 'الاجتماعات والضيافة' FROM expense_parent_categories WHERE name_en = 'Other Operating Expenses'
UNION ALL
SELECT id, 'Entertainment & Events', 'الترفيه والفعاليات' FROM expense_parent_categories WHERE name_en = 'Other Operating Expenses'
UNION ALL
SELECT id, 'Small Tools & Consumables', 'أدوات ومواد استهلاكية صغيرة' FROM expense_parent_categories WHERE name_en = 'Other Operating Expenses'
UNION ALL
SELECT id, 'Community Sponsorships', 'الرعايات المجتمعية' FROM expense_parent_categories WHERE name_en = 'Other Operating Expenses';

-- Insert Sub Categories for Tax & Compliance
INSERT INTO expense_sub_categories (parent_category_id, name_en, name_ar)
SELECT id, 'VAT Adjustments', 'تعديلات ضريبة القيمة المضافة' FROM expense_parent_categories WHERE name_en = 'Tax & Compliance'
UNION ALL
SELECT id, 'Zakat Expense', 'مصروف الزكاة' FROM expense_parent_categories WHERE name_en = 'Tax & Compliance'
UNION ALL
SELECT id, 'Income Tax Expense', 'مصروف ضريبة الدخل' FROM expense_parent_categories WHERE name_en = 'Tax & Compliance'
UNION ALL
SELECT id, 'Tax Consultancy Fees', 'أتعاب استشارات ضريبية' FROM expense_parent_categories WHERE name_en = 'Tax & Compliance'
UNION ALL
SELECT id, 'Regulatory Filing Fees', 'رسوم الإيداعات النظامية' FROM expense_parent_categories WHERE name_en = 'Tax & Compliance'
UNION ALL
SELECT id, 'Municipality Tax', 'الضريبة البلدية' FROM expense_parent_categories WHERE name_en = 'Tax & Compliance'
UNION ALL
SELECT id, 'Legal Penalties & Fines', 'الغرامات والعقوبات القانونية' FROM expense_parent_categories WHERE name_en = 'Tax & Compliance';

-- Enable Row Level Security (RLS)
ALTER TABLE expense_parent_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_sub_categories ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users to read categories
CREATE POLICY "Allow authenticated users to read parent categories"
ON expense_parent_categories FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Allow authenticated users to read sub categories"
ON expense_sub_categories FOR SELECT
TO authenticated
USING (true);

-- Create policies for admin users to manage categories (you can adjust based on your auth structure)
CREATE POLICY "Allow admin users to insert parent categories"
ON expense_parent_categories FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Allow admin users to update parent categories"
ON expense_parent_categories FOR UPDATE
TO authenticated
USING (true);

CREATE POLICY "Allow admin users to delete parent categories"
ON expense_parent_categories FOR DELETE
TO authenticated
USING (true);

CREATE POLICY "Allow admin users to insert sub categories"
ON expense_sub_categories FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Allow admin users to update sub categories"
ON expense_sub_categories FOR UPDATE
TO authenticated
USING (true);

CREATE POLICY "Allow admin users to delete sub categories"
ON expense_sub_categories FOR DELETE
TO authenticated
USING (true);

-- Add comment for documentation
COMMENT ON TABLE expense_parent_categories IS 'Parent expense categories with bilingual support (English and Arabic)';
COMMENT ON TABLE expense_sub_categories IS 'Sub expense categories linked to parent categories with bilingual support';
