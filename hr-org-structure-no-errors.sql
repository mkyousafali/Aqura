-- =====================================================
-- FINAL HR ORGANIZATIONAL STRUCTURE - SUBQUERY ERROR FIXED
-- Run this after hr-master-schema-minimal.sql
-- =====================================================

-- Clear existing data first to prevent duplicates and conflicts
DELETE FROM hr_position_reporting_template WHERE id IS NOT NULL;
DELETE FROM hr_positions WHERE id IS NOT NULL;
DELETE FROM hr_levels WHERE id IS NOT NULL;
DELETE FROM hr_departments WHERE id IS NOT NULL;

-- =====================================================
-- STEP 1: INSERT DEPARTMENTS
-- =====================================================
INSERT INTO hr_departments (department_name_en, department_name_ar) VALUES
('Executive Leadership', 'القيادة التنفيذية'),
('Senior Management', 'الإدارة العليا'),
('Core Management & Strategy', 'الإدارة الأساسية والاستراتيجية'),
('Quality & Compliance', 'الجودة والامتثال'),
('Branch Operations', 'عمليات الفروع'),
('Store Departments', 'أقسام المتجر'),
('Store Supervisors', 'مشرفو المتجر'),
('Store Staff', 'موظفو المتجر');

-- =====================================================
-- STEP 2: INSERT LEVELS
-- =====================================================
INSERT INTO hr_levels (level_name_en, level_name_ar, level_order) VALUES
('Executive Leadership', 'القيادة التنفيذية', 1),
('Senior Management', 'الإدارة العليا', 2),
('Core Management & Strategy', 'الإدارة الأساسية والاستراتيجية', 3),
('Quality & Compliance', 'الجودة والامتثال', 4),
('Branch Leadership', 'قيادة الفروع', 5),
('Store Departments (Heads)', 'رؤساء أقسام المتجر', 6),
('Store Supervisors', 'مشرفو المتجر', 7),
('Store Staff', 'موظفو المتجر', 8);

-- =====================================================
-- STEP 3: INSERT POSITIONS WITH PROPER REFERENCES
-- =====================================================

-- Variables for department and level IDs (using WITH clause for clarity)
WITH dept_ids AS (
  SELECT 
    id,
    department_name_en,
    ROW_NUMBER() OVER (PARTITION BY department_name_en ORDER BY created_at) as rn
  FROM hr_departments
),
level_ids AS (
  SELECT 
    id,
    level_order,
    ROW_NUMBER() OVER (PARTITION BY level_order ORDER BY created_at) as rn  
  FROM hr_levels
)
INSERT INTO hr_positions (position_title_en, position_title_ar, department_id, level_id) 
SELECT * FROM (VALUES
-- Level 1: Executive Leadership
('Owner / Chairman', 'المالك / رئيس مجلس الإدارة', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Executive Leadership' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 1 AND rn = 1)),
('CEO', 'الرئيس التنفيذي', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Executive Leadership' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 1 AND rn = 1)),

-- Level 2: Senior Management  
('General Manager (GM)', 'المدير العام', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Senior Management' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 2 AND rn = 1)),
('Operations Manager', 'مدير العمليات', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Senior Management' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 2 AND rn = 1)),

-- Level 3: Core Management & Strategy
('Purchasing Manager', 'مدير المشتريات', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Core Management & Strategy' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 3 AND rn = 1)),
('Finance Manager', 'مدير الشؤون المالية', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Core Management & Strategy' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 3 AND rn = 1)),
('HR Manager', 'مدير الموارد البشرية', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Core Management & Strategy' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 3 AND rn = 1)),
('Marketing Manager', 'مدير التسويق', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Core Management & Strategy' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 3 AND rn = 1)),
('IT Systems Manager', 'مدير أنظمة تكنولوجيا المعلومات', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Core Management & Strategy' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 3 AND rn = 1)),
('Legal & Compliance Officers', 'مسؤولو القانونية والامتثال', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Core Management & Strategy' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 3 AND rn = 1)),
('Analytics & Business Intelligence', 'التحليلات وذكاء الأعمال', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Core Management & Strategy' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 3 AND rn = 1)),

-- Level 4: Quality & Compliance
('Quality Assurance Manager', 'مدير ضمان الجودة', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Quality & Compliance' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 4 AND rn = 1)),
('Quality Assurance Checkers', 'مفتشو ضمان الجودة', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Quality & Compliance' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 4 AND rn = 1)),

-- Level 5: Branch Leadership
('Branch Manager', 'مدير الفرع', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Branch Operations' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 5 AND rn = 1)),
('Inventory Manager', 'مدير المخزون', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Branch Operations' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 5 AND rn = 1)),

-- Level 6: Store Departments (Heads)
('Cheese Department Head', 'رئيس قسم الجبن', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Departments' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 6 AND rn = 1)),
('Vegetable Department Head', 'رئيس قسم الخضروات', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Departments' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 6 AND rn = 1)),
('Bakery Department Head', 'رئيس قسم المخبز', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Departments' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 6 AND rn = 1)),

-- Level 7: Store Supervisors
('Night Supervisors', 'مشرفو الليل', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Supervisors' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 7 AND rn = 1)),
('Customer Service Supervisor', 'مشرف خدمة العملاء', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Supervisors' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 7 AND rn = 1)),
('Inventory Control Supervisor', 'مشرف مراقبة المخزون', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Supervisors' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 7 AND rn = 1)),

-- Level 8: Store Staff
('Accountant', 'محاسب', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Staff' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 8 AND rn = 1)),
('Driver', 'سائق', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Staff' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 8 AND rn = 1)),
('Cashiers', 'أمين صندوق', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Staff' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 8 AND rn = 1)),
('Checkout Helpers', 'مساعدو الخروج', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Staff' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 8 AND rn = 1)),
('Shelf Stockers', 'عمال تخزين الرفوف', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Staff' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 8 AND rn = 1)),
('Bakers', 'خبازون', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Staff' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 8 AND rn = 1)),
('Warehouse & Stock Handlers', 'عمال المستودع والمخزون', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Staff' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 8 AND rn = 1)),
('Cleaners', 'عمال النظافة', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Staff' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 8 AND rn = 1)),
('Delivery Staff', 'موظفو التوصيل', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Staff' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 8 AND rn = 1)),
('Cheese Counter Staff', 'موظفو منضدة الجبن', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Staff' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 8 AND rn = 1)),
('Vegetable Counter Staff', 'موظفو منضدة الخضروات', 
 (SELECT id FROM dept_ids WHERE department_name_en = 'Store Staff' AND rn = 1), 
 (SELECT id FROM level_ids WHERE level_order = 8 AND rn = 1))
) AS t(position_title_en, position_title_ar, department_id, level_id);

-- =====================================================
-- STEP 4: CREATE SIMPLE POSITION LOOKUP FUNCTION
-- =====================================================
CREATE OR REPLACE FUNCTION get_position_id(position_name TEXT) 
RETURNS UUID AS $$
BEGIN
  RETURN (SELECT id FROM hr_positions WHERE position_title_en = position_name LIMIT 1);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- STEP 5: INSERT REPORTING STRUCTURE USING FUNCTION
-- =====================================================
INSERT INTO hr_position_reporting_template (subordinate_position_id, manager_position_1, manager_position_2, manager_position_3, manager_position_4, manager_position_5) VALUES
-- Top level
(get_position_id('Owner / Chairman'), NULL, NULL, NULL, NULL, NULL),
(get_position_id('CEO'), get_position_id('Owner / Chairman'), NULL, NULL, NULL, NULL),
(get_position_id('General Manager (GM)'), get_position_id('CEO'), NULL, NULL, NULL, NULL),
(get_position_id('Operations Manager'), get_position_id('General Manager (GM)'), NULL, NULL, NULL, NULL),

-- Core Management
(get_position_id('Purchasing Manager'), get_position_id('Operations Manager'), NULL, NULL, NULL, NULL),
(get_position_id('Finance Manager'), get_position_id('Operations Manager'), NULL, NULL, NULL, NULL),
(get_position_id('HR Manager'), get_position_id('Operations Manager'), NULL, NULL, NULL, NULL),
(get_position_id('Marketing Manager'), get_position_id('Operations Manager'), NULL, NULL, NULL, NULL),
(get_position_id('IT Systems Manager'), get_position_id('Operations Manager'), NULL, NULL, NULL, NULL),
(get_position_id('Legal & Compliance Officers'), get_position_id('Operations Manager'), NULL, NULL, NULL, NULL),
(get_position_id('Analytics & Business Intelligence'), get_position_id('Operations Manager'), NULL, NULL, NULL, NULL),

-- Quality
(get_position_id('Quality Assurance Manager'), get_position_id('Operations Manager'), NULL, NULL, NULL, NULL),
(get_position_id('Quality Assurance Checkers'), get_position_id('Quality Assurance Manager'), NULL, NULL, NULL, NULL),

-- Branch Operations
(get_position_id('Branch Manager'), get_position_id('Operations Manager'), NULL, NULL, NULL, NULL),
(get_position_id('Inventory Manager'), get_position_id('Branch Manager'), NULL, NULL, NULL, NULL),

-- Department Heads
(get_position_id('Cheese Department Head'), get_position_id('Branch Manager'), NULL, NULL, NULL, NULL),
(get_position_id('Vegetable Department Head'), get_position_id('Branch Manager'), NULL, NULL, NULL, NULL),
(get_position_id('Bakery Department Head'), get_position_id('Branch Manager'), NULL, NULL, NULL, NULL),

-- Supervisors
(get_position_id('Night Supervisors'), get_position_id('Branch Manager'), NULL, NULL, NULL, NULL),
(get_position_id('Customer Service Supervisor'), get_position_id('Branch Manager'), NULL, NULL, NULL, NULL),
(get_position_id('Inventory Control Supervisor'), get_position_id('Inventory Manager'), NULL, NULL, NULL, NULL),

-- Store Staff
(get_position_id('Accountant'), get_position_id('Finance Manager'), NULL, NULL, NULL, NULL),
(get_position_id('Driver'), get_position_id('Branch Manager'), NULL, NULL, NULL, NULL),
(get_position_id('Cashiers'), get_position_id('Customer Service Supervisor'), NULL, NULL, NULL, NULL),
(get_position_id('Checkout Helpers'), get_position_id('Customer Service Supervisor'), NULL, NULL, NULL, NULL),
(get_position_id('Bakers'), get_position_id('Bakery Department Head'), NULL, NULL, NULL, NULL),
(get_position_id('Warehouse & Stock Handlers'), get_position_id('Inventory Manager'), NULL, NULL, NULL, NULL),
(get_position_id('Cleaners'), get_position_id('Branch Manager'), NULL, NULL, NULL, NULL),
(get_position_id('Delivery Staff'), get_position_id('Branch Manager'), NULL, NULL, NULL, NULL),
(get_position_id('Cheese Counter Staff'), get_position_id('Cheese Department Head'), NULL, NULL, NULL, NULL),
(get_position_id('Vegetable Counter Staff'), get_position_id('Vegetable Department Head'), NULL, NULL, NULL, NULL),

-- Shelf Stockers with multiple reporting
(get_position_id('Shelf Stockers'), get_position_id('Branch Manager'), get_position_id('Night Supervisors'), get_position_id('Customer Service Supervisor'), NULL, NULL);

-- =====================================================
-- CLEANUP FUNCTION
-- =====================================================
DROP FUNCTION get_position_id(TEXT);

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================
SELECT 'SUCCESS: Departments inserted' as status, COUNT(*) as count FROM hr_departments;
SELECT 'SUCCESS: Levels inserted' as status, COUNT(*) as count FROM hr_levels;
SELECT 'SUCCESS: Positions inserted' as status, COUNT(*) as count FROM hr_positions;
SELECT 'SUCCESS: Reporting structure inserted' as status, COUNT(*) as count FROM hr_position_reporting_template;

-- Final reporting structure check
SELECT 
    sub.position_title_en as position,
    mgr1.position_title_en as reports_to_1,
    mgr2.position_title_en as reports_to_2,
    mgr3.position_title_en as reports_to_3
FROM hr_position_reporting_template t
JOIN hr_positions sub ON t.subordinate_position_id = sub.id
LEFT JOIN hr_positions mgr1 ON t.manager_position_1 = mgr1.id
LEFT JOIN hr_positions mgr2 ON t.manager_position_2 = mgr2.id
LEFT JOIN hr_positions mgr3 ON t.manager_position_3 = mgr3.id
ORDER BY sub.position_title_en;