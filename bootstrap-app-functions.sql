-- Bootstrap script to populate app_functions and create initial system setup
-- Run this after setting up the dynamic user-management-schema.sql

-- =====================================================
-- STEP 1: CREATE SYSTEM ROLES
-- =====================================================

-- Create system roles first (these are required for admin users)
SELECT register_system_role(
    'Master Admin', 
    'MASTER_ADMIN', 
    'Full system access with all permissions'
);

SELECT register_system_role(
    'Admin', 
    'ADMIN', 
    'Administrative access with most permissions'
);

-- =====================================================
-- STEP 2: REGISTER APP FUNCTIONS
-- =====================================================

-- Core system functions (always needed)
SELECT register_app_function(
    'Dashboard Access', 
    'DASHBOARD', 
    'Main dashboard and navigation access', 
    'System'
);

SELECT register_app_function(
    'User Management', 
    'USER_MGMT', 
    'Manage user accounts and permissions', 
    'Administration'
);

SELECT register_app_function(
    'System Settings', 
    'SETTINGS', 
    'System configuration and preferences', 
    'Administration'
);

-- Master Data Management functions (from sidebar)
SELECT register_app_function(
    'Branch Master', 
    'BRANCH_MASTER', 
    'Manage company branches and locations', 
    'Master Data'
);

SELECT register_app_function(
    'HR Master', 
    'HR_MASTER', 
    'Human resources master data management', 
    'Master Data'
);

SELECT register_app_function(
    'Task Master', 
    'TASK_MASTER', 
    'Task and workflow management', 
    'Master Data'
);

-- HR Management Sub-modules (discovered from HRMaster component)
SELECT register_app_function(
    'Upload Employees', 
    'UPLOAD_EMPLOYEES', 
    'Import employees from Excel files', 
    'HR'
);

SELECT register_app_function(
    'Create Department', 
    'CREATE_DEPARTMENT', 
    'Create and manage departments', 
    'HR'
);

SELECT register_app_function(
    'Create Level', 
    'CREATE_LEVEL', 
    'Define organizational hierarchy levels', 
    'HR'
);

SELECT register_app_function(
    'Create Position', 
    'CREATE_POSITION', 
    'Set up job positions and roles', 
    'HR'
);

SELECT register_app_function(
    'Reporting Map', 
    'REPORTING_MAP', 
    'Define reporting relationships and hierarchy', 
    'HR'
);

SELECT register_app_function(
    'Assign Positions', 
    'ASSIGN_POSITIONS', 
    'Assign positions to employees', 
    'HR'
);

SELECT register_app_function(
    'Upload Fingerprint', 
    'UPLOAD_FINGERPRINT', 
    'Upload fingerprint transaction data', 
    'HR'
);

SELECT register_app_function(
    'Contact Management', 
    'CONTACT_MANAGEMENT', 
    'Manage employee contact information', 
    'HR'
);

SELECT register_app_function(
    'Document Management', 
    'DOCUMENT_MANAGEMENT', 
    'Manage employee documents and files', 
    'HR'
);

SELECT register_app_function(
    'Salary Management', 
    'SALARY_MANAGEMENT', 
    'Employee salary and allowances management', 
    'HR'
);

-- User Management Sub-components (discovered from UserManagement component)
SELECT register_app_function(
    'Create User', 
    'CREATE_USER', 
    'Create new user accounts', 
    'Administration'
);

SELECT register_app_function(
    'Edit User', 
    'EDIT_USER', 
    'Modify existing user accounts', 
    'Administration'
);

SELECT register_app_function(
    'Assign Roles', 
    'ASSIGN_ROLES', 
    'Assign roles and permissions to users', 
    'Administration'
);

SELECT register_app_function(
    'Create User Roles', 
    'CREATE_USER_ROLES', 
    'Create and configure user roles with permissions', 
    'Administration'
);

SELECT register_app_function(
    'Manage Admin Users', 
    'MANAGE_ADMIN_USERS', 
    'Manage administrative user accounts', 
    'Administration'
);

SELECT register_app_function(
    'Manage Master Admin', 
    'MANAGE_MASTER_ADMIN', 
    'Manage master administrator accounts', 
    'Administration'
);

-- Other modules from sidebar
SELECT register_app_function(
    'Work Management', 
    'WORK_MGMT', 
    'Work processes and task management', 
    'Operations'
);

SELECT register_app_function(
    'Reports', 
    'REPORTS', 
    'Generate and view business reports', 
    'Reporting'
);

SELECT register_app_function(
    'Data Import', 
    'DATA_IMPORT', 
    'Excel data import capabilities', 
    'System'
);

SELECT register_app_function(
    'Audit Logs', 
    'AUDIT_LOGS', 
    'View system audit logs and activity', 
    'System'
);

-- Show registration results
SELECT 
    af.id,
    af.function_name,
    af.function_code,
    af.category,
    af.is_active,
    af.created_at
FROM app_functions af
ORDER BY af.category, af.function_name;

-- Show count by category
SELECT 
    category,
    COUNT(*) as function_count
FROM app_functions
WHERE is_active = true
GROUP BY category
ORDER BY category;

-- =====================================================
-- STEP 3: CREATE MASTER ADMIN USER
-- =====================================================

-- Create the initial master admin user
SELECT create_system_admin(
    'madmin',              -- username
    '@Madmin709',          -- password
    '491709',              -- quick access code
    'Master Admin'::role_type_enum,  -- role type
    'global'::user_type_enum         -- user type
);

-- =====================================================
-- STEP 4: SETUP ROLE PERMISSIONS
-- =====================================================

-- Grant all permissions to Master Admin role
SELECT setup_role_permissions(
    'MASTER_ADMIN',
    '{"can_view": true, "can_add": true, "can_edit": true, "can_delete": true, "can_export": true}'::JSONB
);

-- Grant most permissions to Admin role (excluding delete)
SELECT setup_role_permissions(
    'ADMIN',
    '{"can_view": true, "can_add": true, "can_edit": true, "can_delete": false, "can_export": true}'::JSONB
);

-- =====================================================
-- STEP 5: VERIFICATION
-- =====================================================

-- Verify master admin user was created
SELECT 
    'Master Admin User' as check_type,
    jsonb_build_object(
        'username', username,
        'role_type', role_type,
        'status', status,
        'user_type', user_type,
        'created_at', created_at
    ) as details
FROM users 
WHERE username = 'madmin';

-- Verify system roles were created
SELECT 
    'System Roles' as check_type,
    jsonb_agg(
        jsonb_build_object(
            'role_name', role_name,
            'role_code', role_code,
            'is_system_role', is_system_role
        )
    ) as details
FROM user_roles 
WHERE is_system_role = true;

-- Verify master admin permissions
SELECT 
    'Master Admin Permissions' as check_type,
    jsonb_build_object(
        'total_functions', COUNT(*),
        'view_permissions', SUM(CASE WHEN rp.can_view THEN 1 ELSE 0 END),
        'add_permissions', SUM(CASE WHEN rp.can_add THEN 1 ELSE 0 END),
        'edit_permissions', SUM(CASE WHEN rp.can_edit THEN 1 ELSE 0 END),
        'delete_permissions', SUM(CASE WHEN rp.can_delete THEN 1 ELSE 0 END),
        'export_permissions', SUM(CASE WHEN rp.can_export THEN 1 ELSE 0 END)
    ) as details
FROM user_roles ur
JOIN role_permissions rp ON ur.id = rp.role_id  
JOIN app_functions af ON rp.function_id = af.id
WHERE ur.role_code = 'MASTER_ADMIN';

RAISE NOTICE '=== BOOTSTRAP COMPLETE ===';
RAISE NOTICE 'Master Admin Login: madmin / @Madmin709';
RAISE NOTICE 'Quick Access Code: 491709';
RAISE NOTICE 'System is ready for use!';
RAISE NOTICE '===============================';