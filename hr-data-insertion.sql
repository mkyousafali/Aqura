-- =====================================================
-- HR MASTER FUNCTIONS - DATA INSERTION PROCESS
-- Step 2: Sample INSERT procedures for HR Tables
-- =====================================================

-- =====================================================
-- 1. INSERT INTO HR DEPARTMENTS
-- =====================================================
-- Actual organizational departments based on business structure
INSERT INTO hr_departments (department_name_en, department_name_ar) VALUES
('Executive Leadership', 'القيادة التنفيذية'),
('Senior Management', 'الإدارة العليا'),
('Core Management & Strategy', 'الإدارة الأساسية والاستراتيجية'),
('Quality & Compliance', 'الجودة والامتثال'),
('Branch Leadership', 'قيادة الفرع'),
('Store Departments (Heads)', 'رؤساء الأقسام داخل المتجر'),
('Store Supervisors', 'مشرفو المتجر'),
('Store Staff', 'موظفو المتجر');

-- =====================================================
-- 2. INSERT INTO HR LEVELS
-- =====================================================
-- Actual organizational levels based on business hierarchy
INSERT INTO hr_levels (level_name_en, level_name_ar, level_order) VALUES
('Executive Leadership', 'القيادة التنفيذية', 1),
('Senior Management', 'الإدارة العليا', 2),
('Core Management & Strategy', 'الإدارة الأساسية والاستراتيجية', 3),
('Quality & Compliance', 'الجودة والامتثال', 4),
('Branch Leadership', 'قيادة الفرع', 5),
('Department Heads', 'رؤساء الأقسام', 6),
('Supervisory Roles', 'الأدوار الإشرافية', 7),
('Store Staff', 'موظفو المتجر', 8);

-- =====================================================
-- 3. INSERT INTO HR POSITIONS
-- =====================================================
-- Actual positions based on organizational structure
DO $$ 
DECLARE 
    dept_exec_leadership UUID;
    dept_senior_mgmt UUID;
    dept_core_mgmt UUID;
    dept_quality UUID;
    dept_branch_leadership UUID;
    dept_store_heads UUID;
    dept_store_supervisors UUID;
    dept_store_staff UUID;
    
    level_exec_leadership UUID;
    level_senior_mgmt UUID;
    level_core_mgmt UUID;
    level_quality UUID;
    level_branch_leadership UUID;
    level_dept_heads UUID;
    level_supervisory UUID;
    level_store_staff UUID;
BEGIN
    -- Get department IDs
    SELECT id INTO dept_exec_leadership FROM hr_departments WHERE department_name_en = 'Executive Leadership';
    SELECT id INTO dept_senior_mgmt FROM hr_departments WHERE department_name_en = 'Senior Management';
    SELECT id INTO dept_core_mgmt FROM hr_departments WHERE department_name_en = 'Core Management & Strategy';
    SELECT id INTO dept_quality FROM hr_departments WHERE department_name_en = 'Quality & Compliance';
    SELECT id INTO dept_branch_leadership FROM hr_departments WHERE department_name_en = 'Branch Leadership';
    SELECT id INTO dept_store_heads FROM hr_departments WHERE department_name_en = 'Store Departments (Heads)';
    SELECT id INTO dept_store_supervisors FROM hr_departments WHERE department_name_en = 'Store Supervisors';
    SELECT id INTO dept_store_staff FROM hr_departments WHERE department_name_en = 'Store Staff';
    
    -- Get level IDs
    SELECT id INTO level_exec_leadership FROM hr_levels WHERE level_name_en = 'Executive Leadership';
    SELECT id INTO level_senior_mgmt FROM hr_levels WHERE level_name_en = 'Senior Management';
    SELECT id INTO level_core_mgmt FROM hr_levels WHERE level_name_en = 'Core Management & Strategy';
    SELECT id INTO level_quality FROM hr_levels WHERE level_name_en = 'Quality & Compliance';
    SELECT id INTO level_branch_leadership FROM hr_levels WHERE level_name_en = 'Branch Leadership';
    SELECT id INTO level_dept_heads FROM hr_levels WHERE level_name_en = 'Department Heads';
    SELECT id INTO level_supervisory FROM hr_levels WHERE level_name_en = 'Supervisory Roles';
    SELECT id INTO level_store_staff FROM hr_levels WHERE level_name_en = 'Store Staff';
    
    -- Insert positions
    INSERT INTO hr_positions (position_title_en, position_title_ar, department_id, level_id) VALUES
    -- Executive Leadership Level
    ('Owner / Chairman', 'المالك / الرئيس', dept_exec_leadership, level_exec_leadership),
    ('CEO', 'الرئيس التنفيذي', dept_exec_leadership, level_exec_leadership),
    
    -- Senior Management Level
    ('General Manager (GM)', 'المدير العام', dept_senior_mgmt, level_senior_mgmt),
    ('Operations Manager', 'مدير العمليات', dept_senior_mgmt, level_senior_mgmt),
    
    -- Core Management & Strategy Level
    ('Purchasing Manager', 'مدير المشتريات', dept_core_mgmt, level_core_mgmt),
    ('Finance Manager', 'مدير المالية', dept_core_mgmt, level_core_mgmt),
    ('HR Manager', 'مدير الموارد البشرية', dept_core_mgmt, level_core_mgmt),
    ('Marketing Manager', 'مدير التسويق', dept_core_mgmt, level_core_mgmt),
    ('IT Systems Manager', 'مدير أنظمة تقنية المعلومات', dept_core_mgmt, level_core_mgmt),
    ('Legal & Compliance Officers', 'موظفو الشؤون القانونية والامتثال', dept_core_mgmt, level_core_mgmt),
    ('Analytics & Business Intelligence', 'التحليلات وذكاء الأعمال', dept_core_mgmt, level_core_mgmt),
    
    -- Quality & Compliance Level
    ('Quality Assurance Manager', 'مدير ضمان الجودة', dept_quality, level_quality),
    ('Quality Assurance Checkers', 'مفتشو ضمان الجودة', dept_quality, level_quality),
    
    -- Branch Leadership Level
    ('Branch Manager', 'مدير الفرع', dept_branch_leadership, level_branch_leadership),
    ('Inventory Manager', 'مدير المخزون', dept_branch_leadership, level_branch_leadership),
    
    -- Store Departments (Heads) Level
    ('Cheese Department Head', 'رئيس قسم الأجبان', dept_store_heads, level_dept_heads),
    ('Vegetable Department Head', 'رئيس قسم الخضروات', dept_store_heads, level_dept_heads),
    ('Bakery Department Head', 'رئيس قسم المخبوزات', dept_store_heads, level_dept_heads),
    
    -- Store Supervisors Level
    ('Night Supervisors', 'مشرفو الليل', dept_store_supervisors, level_supervisory),
    ('Customer Service Supervisor', 'مشرف خدمة العملاء', dept_store_supervisors, level_supervisory),
    ('Inventory Control Supervisor', 'مشرف مراقبة المخزون', dept_store_supervisors, level_supervisory),
    
    -- Store Staff Level
    ('Accountant', 'محاسب', dept_store_staff, level_store_staff),
    ('Driver', 'سائق', dept_store_staff, level_store_staff),
    ('Cashiers', 'أمناء الصندوق', dept_store_staff, level_store_staff),
    ('Checkout Helpers', 'مساعدو الصندوق', dept_store_staff, level_store_staff),
    ('Shelf Stockers', 'مصففو الرفوف', dept_store_staff, level_store_staff),
    ('Bakers', 'خبازون', dept_store_staff, level_store_staff),
    ('Warehouse & Stock Handlers', 'عمال المستودع والمخزون', dept_store_staff, level_store_staff),
    ('Cleaners', 'عمال النظافة', dept_store_staff, level_store_staff),
    ('Delivery Staff', 'موظفو التوصيل', dept_store_staff, level_store_staff),
    ('Cheese Counter Staff', 'موظفو قسم الأجبان', dept_store_staff, level_store_staff),
    ('Vegetable Counter Staff', 'موظفو قسم الخضروات', dept_store_staff, level_store_staff);
END $$;

-- =====================================================
-- 4. INSERT POSITION REPORTING TEMPLATE
-- =====================================================
-- Setup reporting relationships between positions (will be used when assigning actual employees)
DO $$ 
DECLARE 
    -- Position IDs for easy reference
    pos_owner UUID;
    pos_ceo UUID;
    pos_gm UUID;
    pos_ops_manager UUID;
    pos_purchasing_mgr UUID;
    pos_finance_mgr UUID;
    pos_hr_mgr UUID;
    pos_marketing_mgr UUID;
    pos_it_mgr UUID;
    pos_legal UUID;
    pos_analytics UUID;
    pos_qa_mgr UUID;
    pos_qa_checkers UUID;
    pos_branch_mgr UUID;
    pos_inventory_mgr UUID;
    pos_cheese_head UUID;
    pos_veg_head UUID;
    pos_bakery_head UUID;
    pos_night_supervisor UUID;
    pos_cs_supervisor UUID;
    pos_inv_supervisor UUID;
    pos_accountant UUID;
    pos_driver UUID;
    pos_cashiers UUID;
    pos_checkout_helpers UUID;
    pos_shelf_stockers UUID;
    pos_bakers UUID;
    pos_warehouse UUID;
    pos_cleaners UUID;
    pos_delivery UUID;
    pos_cheese_staff UUID;
    pos_veg_staff UUID;
BEGIN
    -- Get all position IDs
    SELECT id INTO pos_owner FROM hr_positions WHERE position_title_en = 'Owner / Chairman';
    SELECT id INTO pos_ceo FROM hr_positions WHERE position_title_en = 'CEO';
    SELECT id INTO pos_gm FROM hr_positions WHERE position_title_en = 'General Manager (GM)';
    SELECT id INTO pos_ops_manager FROM hr_positions WHERE position_title_en = 'Operations Manager';
    SELECT id INTO pos_purchasing_mgr FROM hr_positions WHERE position_title_en = 'Purchasing Manager';
    SELECT id INTO pos_finance_mgr FROM hr_positions WHERE position_title_en = 'Finance Manager';
    SELECT id INTO pos_hr_mgr FROM hr_positions WHERE position_title_en = 'HR Manager';
    SELECT id INTO pos_marketing_mgr FROM hr_positions WHERE position_title_en = 'Marketing Manager';
    SELECT id INTO pos_it_mgr FROM hr_positions WHERE position_title_en = 'IT Systems Manager';
    SELECT id INTO pos_legal FROM hr_positions WHERE position_title_en = 'Legal & Compliance Officers';
    SELECT id INTO pos_analytics FROM hr_positions WHERE position_title_en = 'Analytics & Business Intelligence';
    SELECT id INTO pos_qa_mgr FROM hr_positions WHERE position_title_en = 'Quality Assurance Manager';
    SELECT id INTO pos_qa_checkers FROM hr_positions WHERE position_title_en = 'Quality Assurance Checkers';
    SELECT id INTO pos_branch_mgr FROM hr_positions WHERE position_title_en = 'Branch Manager';
    SELECT id INTO pos_inventory_mgr FROM hr_positions WHERE position_title_en = 'Inventory Manager';
    SELECT id INTO pos_cheese_head FROM hr_positions WHERE position_title_en = 'Cheese Department Head';
    SELECT id INTO pos_veg_head FROM hr_positions WHERE position_title_en = 'Vegetable Department Head';
    SELECT id INTO pos_bakery_head FROM hr_positions WHERE position_title_en = 'Bakery Department Head';
    SELECT id INTO pos_night_supervisor FROM hr_positions WHERE position_title_en = 'Night Supervisors';
    SELECT id INTO pos_cs_supervisor FROM hr_positions WHERE position_title_en = 'Customer Service Supervisor';
    SELECT id INTO pos_inv_supervisor FROM hr_positions WHERE position_title_en = 'Inventory Control Supervisor';
    SELECT id INTO pos_accountant FROM hr_positions WHERE position_title_en = 'Accountant';
    SELECT id INTO pos_driver FROM hr_positions WHERE position_title_en = 'Driver';
    SELECT id INTO pos_cashiers FROM hr_positions WHERE position_title_en = 'Cashiers';
    SELECT id INTO pos_checkout_helpers FROM hr_positions WHERE position_title_en = 'Checkout Helpers';
    SELECT id INTO pos_shelf_stockers FROM hr_positions WHERE position_title_en = 'Shelf Stockers';
    SELECT id INTO pos_bakers FROM hr_positions WHERE position_title_en = 'Bakers';
    SELECT id INTO pos_warehouse FROM hr_positions WHERE position_title_en = 'Warehouse & Stock Handlers';
    SELECT id INTO pos_cleaners FROM hr_positions WHERE position_title_en = 'Cleaners';
    SELECT id INTO pos_delivery FROM hr_positions WHERE position_title_en = 'Delivery Staff';
    SELECT id INTO pos_cheese_staff FROM hr_positions WHERE position_title_en = 'Cheese Counter Staff';
    SELECT id INTO pos_veg_staff FROM hr_positions WHERE position_title_en = 'Vegetable Counter Staff';
    
    -- Insert position reporting relationships
    INSERT INTO hr_position_reporting_template (subordinate_position_id, manager_position_id, is_primary) VALUES
    -- Level 1: Executive Leadership
    -- Owner/Chairman → Not assigned (Top Authority) - no entry needed
    (pos_ceo, pos_owner, true), -- CEO → Owner/Chairman
    
    -- Level 2: Senior Management  
    (pos_gm, pos_ceo, true), -- General Manager (GM) → CEO
    (pos_ops_manager, pos_gm, true), -- Operations Manager → General Manager (GM)
    
    -- Level 3: Core Management & Strategy → Operations Manager
    (pos_purchasing_mgr, pos_ops_manager, true),
    (pos_finance_mgr, pos_ops_manager, true),
    (pos_hr_mgr, pos_ops_manager, true),
    (pos_marketing_mgr, pos_ops_manager, true),
    (pos_it_mgr, pos_ops_manager, true),
    (pos_legal, pos_ops_manager, true),
    (pos_analytics, pos_ops_manager, true),
    
    -- Level 4: Quality & Compliance
    (pos_qa_mgr, pos_ops_manager, true), -- Quality Assurance Manager → Operations Manager
    (pos_qa_checkers, pos_qa_mgr, true), -- Quality Assurance Checkers → Quality Assurance Manager
    
    -- Level 5: Branch Leadership
    (pos_branch_mgr, pos_ops_manager, true), -- Branch Manager → Operations Manager
    (pos_inventory_mgr, pos_branch_mgr, true), -- Inventory Manager → Branch Manager
    
    -- Level 6: Store Departments (Heads) → Branch Manager
    (pos_cheese_head, pos_branch_mgr, true),
    (pos_veg_head, pos_branch_mgr, true),
    (pos_bakery_head, pos_branch_mgr, true),
    
    -- Level 7: Store Supervisors
    (pos_night_supervisor, pos_branch_mgr, true), -- Night Supervisors → Branch Manager
    (pos_cs_supervisor, pos_branch_mgr, true), -- Customer Service Supervisor → Branch Manager
    (pos_inv_supervisor, pos_inventory_mgr, true), -- Inventory Control Supervisor → Inventory Manager
    
    -- Level 8: Store Staff
    (pos_accountant, pos_finance_mgr, true), -- Accountant → Finance Manager (Central)
    (pos_driver, pos_branch_mgr, true), -- Driver → Branch Manager
    (pos_cashiers, pos_cs_supervisor, true), -- Cashiers → Customer Service Supervisor
    (pos_checkout_helpers, pos_cs_supervisor, true), -- Checkout Helpers → Customer Service Supervisor
    
    -- Shelf Stockers - Multiple reporting relationships
    (pos_shelf_stockers, pos_branch_mgr, true), -- Primary: Shelf Stockers → Branch Manager
    (pos_shelf_stockers, pos_night_supervisor, false), -- Secondary: Shelf Stockers → Night Supervisors
    (pos_shelf_stockers, pos_cs_supervisor, false), -- Secondary: Shelf Stockers → Customer Service Supervisor
    
    (pos_bakers, pos_bakery_head, true), -- Bakers → Bakery Department Head
    (pos_warehouse, pos_inventory_mgr, true), -- Warehouse & Stock Handlers → Inventory Manager
    (pos_cleaners, pos_branch_mgr, true), -- Cleaners → Branch Manager
    (pos_delivery, pos_branch_mgr, true), -- Delivery Staff → Branch Manager
    (pos_cheese_staff, pos_cheese_head, true), -- Cheese Counter Staff → Cheese Department Head
    (pos_veg_staff, pos_veg_head, true); -- Vegetable Counter Staff → Vegetable Department Head
END $$;

-- =====================================================
-- MESSAGE: ORGANIZATIONAL STRUCTURE INSERTED
-- =====================================================
-- The following organizational structure has been inserted:
-- ✅ 8 Departments (Executive Leadership → Store Staff hierarchy)
-- ✅ 8 Organizational Levels (ranked 1-8 by hierarchy)
-- ✅ 30 Positions (complete organizational positions)
--
-- ORGANIZATIONAL HIERARCHY:
-- Level 1: Executive Leadership (Owner/Chairman, CEO)
-- Level 2: Senior Management (GM, Operations Manager)
-- Level 3: Core Management (Purchasing, Finance, HR, Marketing, IT, Legal, Analytics)
-- Level 4: Quality & Compliance (QA Manager, QA Checkers)
-- Level 5: Branch Leadership (Branch Manager, Inventory Manager)
-- Level 6: Department Heads (Cheese, Vegetable, Bakery Heads)
-- Level 7: Supervisory Roles (Night, Customer Service, Inventory Supervisors)
-- Level 8: Store Staff (11 different positions)
--
-- =====================================================
-- 4. SAMPLE REPORTING RELATIONSHIPS SETUP
-- =====================================================
-- This shows the reporting structure for reference when creating actual employees

-- REPORTING STRUCTURE TEMPLATE:
-- Level 1: Executive Leadership
-- - Owner/Chairman → Not assigned (Top Authority)
-- - CEO → Owner/Chairman

-- Level 2: Senior Management  
-- - General Manager (GM) → CEO
-- - Operations Manager → General Manager (GM)

-- Level 3: Core Management & Strategy
-- - Purchasing Manager → Operations Manager
-- - Finance Manager → Operations Manager
-- - HR Manager → Operations Manager
-- - Marketing Manager → Operations Manager
-- - IT Systems Manager → Operations Manager
-- - Legal & Compliance Officers → Operations Manager
-- - Analytics & Business Intelligence → Operations Manager

-- Level 4: Quality & Compliance
-- - Quality Assurance Manager → Operations Manager
-- - Quality Assurance Checkers → Quality Assurance Manager

-- Level 5: Branch Leadership
-- - Branch Manager → Operations Manager
-- - Inventory Manager → Branch Manager

-- Level 6: Store Departments (Heads)
-- - Cheese Department Head → Branch Manager
-- - Vegetable Department Head → Branch Manager
-- - Bakery Department Head → Branch Manager

-- Level 7: Store Supervisors
-- - Night Supervisors → Branch Manager
-- - Customer Service Supervisor → Branch Manager
-- - Inventory Control Supervisor → Inventory Manager

-- Level 8: Store Staff
-- - Accountant → Finance Manager (Central)
-- - Driver → Branch Manager
-- - Cashiers → Customer Service Supervisor
-- - Checkout Helpers → Customer Service Supervisor
-- - Shelf Stockers → Branch Manager / Night Supervisors / Customer Service Supervisor (Multiple reporting)
-- - Bakers → Bakery Department Head
-- - Warehouse & Stock Handlers → Inventory Manager
-- - Cleaners → Branch Manager
-- - Delivery Staff → Branch Manager
-- - Cheese Counter Staff → Cheese Department Head
-- - Vegetable Counter Staff → Vegetable Department Head

-- =====================================================
-- NEXT STEPS:
-- 1. Ready to add actual employees to hr_employees table
-- 2. Ready to create position assignments
-- 3. Ready to setup reporting relationships in hr_reporting_map table
-- 4. Continue with other HR functions (contacts, documents, etc.)
--
-- USER ACTION REQUIRED:
-- Please provide employee data or say "continue" to proceed with next step.
-- =====================================================