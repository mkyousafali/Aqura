-- =====================================================
-- COMPLETE ORGANIZATIONAL STRUCTURE WITH REPORTING MAP
-- =====================================================

-- First, let's populate the organizational structure data
-- Departments (8 total)
INSERT INTO hr_departments (department_name_en, department_name_ar) VALUES
('Executive Leadership', 'القيادة التنفيذية'),
('Senior Management', 'الإدارة العليا'),
('Core Management & Strategy', 'الإدارة الأساسية والاستراتيجية'),
('Quality & Compliance', 'الجودة والامتثال'),
('Branch Operations', 'عمليات الفروع'),
('Store Departments', 'أقسام المتجر'),
('Store Supervisors', 'مشرفو المتجر'),
('Store Staff', 'موظفو المتجر');

-- Organizational Levels (8 levels)
INSERT INTO hr_levels (level_name_en, level_name_ar, level_order) VALUES
('Executive Leadership', 'القيادة التنفيذية', 1),
('Senior Management', 'الإدارة العليا', 2),
('Core Management & Strategy', 'الإدارة الأساسية والاستراتيجية', 3),
('Quality & Compliance', 'الجودة والامتثال', 4),
('Branch Leadership', 'قيادة الفروع', 5),
('Store Departments (Heads)', 'رؤساء أقسام المتجر', 6),
('Store Supervisors', 'مشرفو المتجر', 7),
('Store Staff', 'موظفو المتجر', 8);

-- All Positions with Reporting Structure (30 positions)
INSERT INTO hr_positions (position_title_en, position_title_ar, department_id, level_id) VALUES
-- Level 1: Executive Leadership
('Owner / Chairman', 'المالك / رئيس مجلس الإدارة', (SELECT id FROM hr_departments WHERE department_name_en = 'Executive Leadership'), (SELECT id FROM hr_levels WHERE level_order = 1)),
('CEO', 'الرئيس التنفيذي', (SELECT id FROM hr_departments WHERE department_name_en = 'Executive Leadership'), (SELECT id FROM hr_levels WHERE level_order = 1)),

-- Level 2: Senior Management  
('General Manager (GM)', 'المدير العام', (SELECT id FROM hr_departments WHERE department_name_en = 'Senior Management'), (SELECT id FROM hr_levels WHERE level_order = 2)),
('Operations Manager', 'مدير العمليات', (SELECT id FROM hr_departments WHERE department_name_en = 'Senior Management'), (SELECT id FROM hr_levels WHERE level_order = 2)),

-- Level 3: Core Management & Strategy
('Purchasing Manager', 'مدير المشتريات', (SELECT id FROM hr_departments WHERE department_name_en = 'Core Management & Strategy'), (SELECT id FROM hr_levels WHERE level_order = 3)),
('Finance Manager', 'مدير الشؤون المالية', (SELECT id FROM hr_departments WHERE department_name_en = 'Core Management & Strategy'), (SELECT id FROM hr_levels WHERE level_order = 3)),
('HR Manager', 'مدير الموارد البشرية', (SELECT id FROM hr_departments WHERE department_name_en = 'Core Management & Strategy'), (SELECT id FROM hr_levels WHERE level_order = 3)),
('Marketing Manager', 'مدير التسويق', (SELECT id FROM hr_departments WHERE department_name_en = 'Core Management & Strategy'), (SELECT id FROM hr_levels WHERE level_order = 3)),
('IT Systems Manager', 'مدير أنظمة تكنولوجيا المعلومات', (SELECT id FROM hr_departments WHERE department_name_en = 'Core Management & Strategy'), (SELECT id FROM hr_levels WHERE level_order = 3)),
('Legal & Compliance Officers', 'مسؤولو القانونية والامتثال', (SELECT id FROM hr_departments WHERE department_name_en = 'Core Management & Strategy'), (SELECT id FROM hr_levels WHERE level_order = 3)),
('Analytics & Business Intelligence', 'التحليلات وذكاء الأعمال', (SELECT id FROM hr_departments WHERE department_name_en = 'Core Management & Strategy'), (SELECT id FROM hr_levels WHERE level_order = 3)),

-- Level 4: Quality & Compliance
('Quality Assurance Manager', 'مدير ضمان الجودة', (SELECT id FROM hr_departments WHERE department_name_en = 'Quality & Compliance'), (SELECT id FROM hr_levels WHERE level_order = 4)),
('Quality Assurance Checkers', 'مفتشو ضمان الجودة', (SELECT id FROM hr_departments WHERE department_name_en = 'Quality & Compliance'), (SELECT id FROM hr_levels WHERE level_order = 4)),

-- Level 5: Branch Leadership
('Branch Manager', 'مدير الفرع', (SELECT id FROM hr_departments WHERE department_name_en = 'Branch Operations'), (SELECT id FROM hr_levels WHERE level_order = 5)),
('Inventory Manager', 'مدير المخزون', (SELECT id FROM hr_departments WHERE department_name_en = 'Branch Operations'), (SELECT id FROM hr_levels WHERE level_order = 5)),

-- Level 6: Store Departments (Heads)
('Cheese Department Head', 'رئيس قسم الجبن', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Departments'), (SELECT id FROM hr_levels WHERE level_order = 6)),
('Vegetable Department Head', 'رئيس قسم الخضروات', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Departments'), (SELECT id FROM hr_levels WHERE level_order = 6)),
('Bakery Department Head', 'رئيس قسم المخبز', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Departments'), (SELECT id FROM hr_levels WHERE level_order = 6)),

-- Level 7: Store Supervisors
('Night Supervisors', 'مشرفو الليل', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Supervisors'), (SELECT id FROM hr_levels WHERE level_order = 7)),
('Customer Service Supervisor', 'مشرف خدمة العملاء', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Supervisors'), (SELECT id FROM hr_levels WHERE level_order = 7)),
('Inventory Control Supervisor', 'مشرف مراقبة المخزون', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Supervisors'), (SELECT id FROM hr_levels WHERE level_order = 7)),

-- Level 8: Store Staff
('Accountant', 'محاسب', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Staff'), (SELECT id FROM hr_levels WHERE level_order = 8)),
('Driver', 'سائق', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Staff'), (SELECT id FROM hr_levels WHERE level_order = 8)),
('Cashiers', 'أمين صندوق', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Staff'), (SELECT id FROM hr_levels WHERE level_order = 8)),
('Checkout Helpers', 'مساعدو الخروج', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Staff'), (SELECT id FROM hr_levels WHERE level_order = 8)),
('Shelf Stockers', 'عمال تخزين الرفوف', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Staff'), (SELECT id FROM hr_levels WHERE level_order = 8)),
('Bakers', 'خبازون', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Staff'), (SELECT id FROM hr_levels WHERE level_order = 8)),
('Warehouse & Stock Handlers', 'عمال المستودع والمخزون', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Staff'), (SELECT id FROM hr_levels WHERE level_order = 8)),
('Cleaners', 'عمال النظافة', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Staff'), (SELECT id FROM hr_levels WHERE level_order = 8)),
('Delivery Staff', 'موظفو التوصيل', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Staff'), (SELECT id FROM hr_levels WHERE level_order = 8)),
('Cheese Counter Staff', 'موظفو منضدة الجبن', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Staff'), (SELECT id FROM hr_levels WHERE level_order = 8)),
('Vegetable Counter Staff', 'موظفو منضدة الخضروات', (SELECT id FROM hr_departments WHERE department_name_en = 'Store Staff'), (SELECT id FROM hr_levels WHERE level_order = 8));

-- =====================================================
-- POSITION REPORTING TEMPLATE - COMPLETE STRUCTURE
-- =====================================================

-- Clear existing template data first
DELETE FROM hr_position_reporting_template;

-- Insert complete reporting structure based on your organizational chart
INSERT INTO hr_position_reporting_template (subordinate_position_id, manager_position_1_id, manager_position_2_id, manager_position_3_id, manager_position_4_id, manager_position_5_id) VALUES

-- Owner/Chairman has no reporting (top authority)
((SELECT id FROM hr_positions WHERE position_title_en = 'Owner / Chairman'), NULL, NULL, NULL, NULL, NULL),

-- CEO reports to Owner/Chairman
((SELECT id FROM hr_positions WHERE position_title_en = 'CEO'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Owner / Chairman'), NULL, NULL, NULL, NULL),

-- General Manager reports to CEO
((SELECT id FROM hr_positions WHERE position_title_en = 'General Manager (GM)'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'CEO'), NULL, NULL, NULL, NULL),

-- Operations Manager reports to General Manager
((SELECT id FROM hr_positions WHERE position_title_en = 'Operations Manager'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'General Manager (GM)'), NULL, NULL, NULL, NULL),

-- Core Management reports to Operations Manager
((SELECT id FROM hr_positions WHERE position_title_en = 'Purchasing Manager'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Operations Manager'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'Finance Manager'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Operations Manager'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'HR Manager'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Operations Manager'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'Marketing Manager'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Operations Manager'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'IT Systems Manager'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Operations Manager'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'Legal & Compliance Officers'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Operations Manager'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'Analytics & Business Intelligence'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Operations Manager'), NULL, NULL, NULL, NULL),

-- Quality Assurance Manager reports to Operations Manager
((SELECT id FROM hr_positions WHERE position_title_en = 'Quality Assurance Manager'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Operations Manager'), NULL, NULL, NULL, NULL),

-- Quality Assurance Checkers report to QA Manager
((SELECT id FROM hr_positions WHERE position_title_en = 'Quality Assurance Checkers'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Quality Assurance Manager'), NULL, NULL, NULL, NULL),

-- Branch Manager reports to Operations Manager
((SELECT id FROM hr_positions WHERE position_title_en = 'Branch Manager'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Operations Manager'), NULL, NULL, NULL, NULL),

-- Inventory Manager reports to Branch Manager
((SELECT id FROM hr_positions WHERE position_title_en = 'Inventory Manager'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Branch Manager'), NULL, NULL, NULL, NULL),

-- Department Heads report to Branch Manager
((SELECT id FROM hr_positions WHERE position_title_en = 'Cheese Department Head'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Branch Manager'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'Vegetable Department Head'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Branch Manager'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'Bakery Department Head'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Branch Manager'), NULL, NULL, NULL, NULL),

-- Supervisors report to Branch Manager
((SELECT id FROM hr_positions WHERE position_title_en = 'Night Supervisors'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Branch Manager'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'Customer Service Supervisor'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Branch Manager'), NULL, NULL, NULL, NULL),

-- Inventory Control Supervisor reports to Inventory Manager
((SELECT id FROM hr_positions WHERE position_title_en = 'Inventory Control Supervisor'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Inventory Manager'), NULL, NULL, NULL, NULL),

-- Store Staff with single reporting
((SELECT id FROM hr_positions WHERE position_title_en = 'Accountant'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Finance Manager'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'Driver'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Branch Manager'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'Cashiers'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Customer Service Supervisor'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'Checkout Helpers'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Customer Service Supervisor'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'Bakers'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Bakery Department Head'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'Warehouse & Stock Handlers'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Inventory Manager'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'Cleaners'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Branch Manager'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'Delivery Staff'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Branch Manager'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'Cheese Counter Staff'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Cheese Department Head'), NULL, NULL, NULL, NULL),
 
((SELECT id FROM hr_positions WHERE position_title_en = 'Vegetable Counter Staff'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Vegetable Department Head'), NULL, NULL, NULL, NULL),

-- Shelf Stockers with MULTIPLE REPORTING (3 managers)
((SELECT id FROM hr_positions WHERE position_title_en = 'Shelf Stockers'), 
 (SELECT id FROM hr_positions WHERE position_title_en = 'Branch Manager'),
 (SELECT id FROM hr_positions WHERE position_title_en = 'Night Supervisors'),
 (SELECT id FROM hr_positions WHERE position_title_en = 'Customer Service Supervisor'), NULL, NULL);

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check all positions are created
SELECT COUNT(*) as total_positions FROM hr_positions;

-- Check reporting structure
SELECT 
    sub.position_title_en as subordinate,
    mgr1.position_title_en as manager_1,
    mgr2.position_title_en as manager_2,
    mgr3.position_title_en as manager_3
FROM hr_position_reporting_template t
JOIN hr_positions sub ON t.subordinate_position_id = sub.id
LEFT JOIN hr_positions mgr1 ON t.manager_position_1_id = mgr1.id
LEFT JOIN hr_positions mgr2 ON t.manager_position_2_id = mgr2.id
LEFT JOIN hr_positions mgr3 ON t.manager_position_3_id = mgr3.id
ORDER BY sub.position_title_en;

-- Check positions by level
SELECT 
    l.level_order,
    l.level_name_en,
    COUNT(p.id) as position_count
FROM hr_levels l
LEFT JOIN hr_positions p ON l.id = p.level_id
GROUP BY l.level_order, l.level_name_en
ORDER BY l.level_order;