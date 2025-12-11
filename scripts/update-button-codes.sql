-- Mapping from database codes to sidebar handler function codes
-- This will align database codes with what the sidebar actually has

UPDATE sidebar_buttons SET button_code = 'BRANCH_MASTER' WHERE button_code = 'BRANCHES';
UPDATE sidebar_buttons SET button_code = 'BRANCH_PERFORMANCE' WHERE button_code = 'BRANCH_PERFORMANCE_WINDOW';
UPDATE sidebar_buttons SET button_code = 'COUPON_DASHBOARD' WHERE button_code = 'COUPON_DASHBOARD_PROMO';
UPDATE sidebar_buttons SET button_code = 'MANAGE_CAMPAIGNS' WHERE button_code = 'CAMPAIGN_MANAGER';
UPDATE sidebar_buttons SET button_code = 'COUPON_REPORTS' WHERE button_code = 'COUPON_REPORTS';
UPDATE sidebar_buttons SET button_code = 'CREATE_TASK_TEMPLATE' WHERE button_code = 'CREATE_TASK';
UPDATE sidebar_buttons SET button_code = 'IMPORT_CUSTOMERS' WHERE button_code = 'CUSTOMER_IMPORTER';
UPDATE sidebar_buttons SET button_code = 'ERP_CONNECTIONS' WHERE button_code = 'E_R_P_CONNECTIONS';
UPDATE sidebar_buttons SET button_code = 'FLYER_MASTER' WHERE button_code = 'FLYER_MASTER';
UPDATE sidebar_buttons SET button_code = 'FLYER_SETTINGS' WHERE button_code = 'FLYER_SETTINGS';
UPDATE sidebar_buttons SET button_code = 'INTERFACE_ACCESS' WHERE button_code = 'INTERFACE_ACCESS_MANAGER';
UPDATE sidebar_buttons SET button_code = 'VIEW_MY_TASKS' WHERE button_code = 'MY_TASKS';
UPDATE sidebar_buttons SET button_code = 'VIEW_MY_ASSIGNMENTS' WHERE button_code = 'MY_ASSIGNMENTS';
UPDATE sidebar_buttons SET button_code = 'OVER_DUES' WHERE button_code = 'OVERDUES_REPORT';
UPDATE sidebar_buttons SET button_code = 'MANAGE_PRODUCTS' WHERE button_code = 'PRODUCT_MANAGER_PROMO';
UPDATE sidebar_buttons SET button_code = 'SALARY_WAGE_MANAGEMENT' WHERE button_code = 'SALARY_MANAGEMENT';
UPDATE sidebar_buttons SET button_code = 'USERS' WHERE button_code = 'USER_MANAGEMENT';
UPDATE sidebar_buttons SET button_code = 'VENDOR_PAYMENTS' WHERE button_code = 'VENDOR_PENDING_PAYMENTS';
UPDATE sidebar_buttons SET button_code = 'VIEW_TASK_TEMPLATES' WHERE button_code = 'VIEW_TASKS';

-- Also add missing buttons that don't exist in database
-- BUTTON_GENERATOR
-- BUTTON_ACCESS_CONTROL (if needed)
