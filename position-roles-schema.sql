-- Position Roles Schema Implementation
-- This script creates the necessary tables and functions to manage position-based roles

-- 1. Create app_functions table (system modules/features)
CREATE TABLE IF NOT EXISTS public.app_functions (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    function_name_en VARCHAR(100) NOT NULL,
    function_name_ar VARCHAR(100) NOT NULL,
    function_code VARCHAR(50) NOT NULL UNIQUE,
    description_en TEXT,
    description_ar TEXT,
    module_category VARCHAR(50) NOT NULL, -- 'user_management', 'inventory', 'sales', etc.
    is_system_function BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create permission_types table
CREATE TABLE IF NOT EXISTS public.permission_types (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    permission_code VARCHAR(20) NOT NULL UNIQUE, -- 'view', 'add', 'edit', 'update', 'delete'
    permission_name_en VARCHAR(50) NOT NULL,
    permission_name_ar VARCHAR(50) NOT NULL,
    description_en TEXT,
    description_ar TEXT,
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Create position_permissions table (main permissions matrix)
CREATE TABLE IF NOT EXISTS public.position_permissions (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    position_id UUID NOT NULL,
    app_function_id UUID NOT NULL,
    permission_type_id UUID NOT NULL,
    is_granted BOOLEAN DEFAULT false,
    granted_by UUID, -- user who granted this permission
    granted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT position_permissions_position_fkey 
        FOREIGN KEY (position_id) REFERENCES hr_positions(id) ON DELETE CASCADE,
    CONSTRAINT position_permissions_function_fkey 
        FOREIGN KEY (app_function_id) REFERENCES app_functions(id) ON DELETE CASCADE,
    CONSTRAINT position_permissions_permission_type_fkey 
        FOREIGN KEY (permission_type_id) REFERENCES permission_types(id) ON DELETE CASCADE,
    CONSTRAINT position_permissions_granted_by_fkey 
        FOREIGN KEY (granted_by) REFERENCES auth.users(id),
    
    -- Unique constraint to prevent duplicates
    CONSTRAINT unique_position_function_permission 
        UNIQUE (position_id, app_function_id, permission_type_id)
);

-- 4. Create audit trail for permission changes
CREATE TABLE IF NOT EXISTS public.position_permissions_audit (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    position_id UUID NOT NULL,
    app_function_id UUID NOT NULL,
    permission_type_id UUID NOT NULL,
    old_value BOOLEAN,
    new_value BOOLEAN,
    changed_by UUID NOT NULL,
    change_reason VARCHAR(255),
    change_type VARCHAR(20) NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT audit_position_fkey FOREIGN KEY (position_id) REFERENCES hr_positions(id),
    CONSTRAINT audit_function_fkey FOREIGN KEY (app_function_id) REFERENCES app_functions(id),
    CONSTRAINT audit_permission_type_fkey FOREIGN KEY (permission_type_id) REFERENCES permission_types(id),
    CONSTRAINT audit_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES auth.users(id)
);

-- 5. Insert default permission types
INSERT INTO public.permission_types (permission_code, permission_name_en, permission_name_ar, description_en, description_ar, display_order) VALUES
('view', 'View', 'عرض', 'View and read data', 'عرض وقراءة البيانات', 1),
('add', 'Add', 'إضافة', 'Create new records', 'إنشاء سجلات جديدة', 2),
('edit', 'Edit', 'تعديل', 'Modify existing records', 'تعديل السجلات الموجودة', 3),
('update', 'Update', 'تحديث', 'Update record status and properties', 'تحديث حالة السجل والخصائص', 4),
('delete', 'Delete', 'حذف', 'Remove records permanently', 'حذف السجلات نهائياً', 5)
ON CONFLICT (permission_code) DO NOTHING;

-- 6. Insert default app functions
INSERT INTO public.app_functions (function_code, function_name_en, function_name_ar, description_en, description_ar, module_category, display_order) VALUES
-- User Management
('user_management', 'User Management', 'إدارة المستخدمين', 'Manage user accounts and permissions', 'إدارة حسابات المستخدمين والصلاحيات', 'user_management', 1),
('admin_management', 'Admin Management', 'إدارة المشرفين', 'Manage administrator accounts', 'إدارة حسابات المشرفين', 'user_management', 2),
('master_admin_tools', 'Master Admin Tools', 'أدوات المشرف الرئيسي', 'System administration tools', 'أدوات إدارة النظام', 'user_management', 3),

-- HR Management
('employee_management', 'Employee Management', 'إدارة الموظفين', 'Manage employee records and information', 'إدارة سجلات ومعلومات الموظفين', 'hr_management', 10),
('payroll_management', 'Payroll Management', 'إدارة الرواتب', 'Process payroll and salary management', 'معالجة الرواتب وإدارة الأجور', 'hr_management', 11),
('attendance_management', 'Attendance Management', 'إدارة الحضور', 'Track employee attendance and time', 'تتبع حضور الموظفين والوقت', 'hr_management', 12),

-- Financial Management
('financial_reports', 'Financial Reports', 'التقارير المالية', 'Access financial reports and analytics', 'الوصول إلى التقارير المالية والتحليلات', 'financial_management', 20),
('accounting_management', 'Accounting Management', 'الإدارة المحاسبية', 'Manage accounting entries and transactions', 'إدارة القيود المحاسبية والمعاملات', 'financial_management', 21),
('budget_management', 'Budget Management', 'إدارة الميزانية', 'Manage budgets and financial planning', 'إدارة الميزانيات والتخطيط المالي', 'financial_management', 22),

-- Inventory Management
('inventory_management', 'Inventory Management', 'إدارة المخزون', 'Track and manage inventory items', 'تتبع وإدارة عناصر المخزون', 'inventory_management', 30),
('supplier_management', 'Supplier Management', 'إدارة الموردين', 'Manage supplier information and orders', 'إدارة معلومات الموردين والطلبات', 'inventory_management', 31),

-- Sales & Customer Management
('sales_transactions', 'Sales Transactions', 'معاملات البيع', 'Process sales and customer transactions', 'معالجة المبيعات ومعاملات العملاء', 'sales_management', 40),
('customer_management', 'Customer Management', 'إدارة العملاء', 'Manage customer information and relationships', 'إدارة معلومات العملاء والعلاقات', 'sales_management', 41),

-- Branch Operations
('branch_operations', 'Branch Operations', 'عمليات الفرع', 'Manage branch-specific operations', 'إدارة العمليات الخاصة بالفرع', 'branch_management', 50),
('cash_management', 'Cash Management', 'إدارة النقدية', 'Manage cash flow and registers', 'إدارة التدفق النقدي والصناديق', 'branch_management', 51),

-- System Administration
('system_settings', 'System Settings', 'إعدادات النظام', 'Configure system-wide settings', 'تكوين إعدادات النظام', 'system_administration', 60),
('audit_logs', 'Audit Logs', 'سجلات التدقيق', 'View system audit logs and activity', 'عرض سجلات تدقيق النظام والنشاط', 'system_administration', 61),
('backup_restore', 'Backup & Restore', 'النسخ الاحتياطي والاستعادة', 'Manage system backups and restoration', 'إدارة النسخ الاحتياطي واستعادة النظام', 'system_administration', 62),
('master_data', 'Master Data', 'البيانات الرئيسية', 'Manage master data and configurations', 'إدارة البيانات الرئيسية والتكوينات', 'system_administration', 63)

ON CONFLICT (function_code) DO NOTHING;

-- 7. Create function to sync user roles from positions (updated version)
CREATE OR REPLACE FUNCTION sync_user_roles_from_positions()
RETURNS TRIGGER AS $$
BEGIN
    -- This function can be used to maintain backward compatibility
    -- or sync with any existing user_roles system if needed
    
    IF TG_OP = 'INSERT' THEN
        -- Log the position creation
        INSERT INTO position_permissions_audit (
            position_id, 
            app_function_id, 
            permission_type_id, 
            old_value, 
            new_value, 
            changed_by, 
            change_type,
            change_reason
        ) VALUES (
            NEW.id,
            (SELECT id FROM app_functions WHERE function_code = 'user_management' LIMIT 1),
            (SELECT id FROM permission_types WHERE permission_code = 'view' LIMIT 1),
            NULL,
            true,
            auth.uid(),
            'INSERT',
            'Position created - default view permission granted'
        );
        
        RETURN NEW;
        
    ELSIF TG_OP = 'UPDATE' THEN
        -- Log position updates if active status changes
        IF OLD.is_active != NEW.is_active THEN
            INSERT INTO position_permissions_audit (
                position_id, 
                app_function_id, 
                permission_type_id, 
                old_value, 
                new_value, 
                changed_by, 
                change_type,
                change_reason
            ) VALUES (
                NEW.id,
                (SELECT id FROM app_functions WHERE function_code = 'user_management' LIMIT 1),
                (SELECT id FROM permission_types WHERE permission_code = 'view' LIMIT 1),
                OLD.is_active,
                NEW.is_active,
                auth.uid(),
                'UPDATE',
                'Position status changed'
            );
        END IF;
        
        RETURN NEW;
        
    ELSIF TG_OP = 'DELETE' THEN
        -- Clean up position permissions when position is deleted
        DELETE FROM position_permissions WHERE position_id = OLD.id;
        
        -- Log the deletion
        INSERT INTO position_permissions_audit (
            position_id, 
            app_function_id, 
            permission_type_id, 
            old_value, 
            new_value, 
            changed_by, 
            change_type,
            change_reason
        ) VALUES (
            OLD.id,
            (SELECT id FROM app_functions WHERE function_code = 'user_management' LIMIT 1),
            (SELECT id FROM permission_types WHERE permission_code = 'view' LIMIT 1),
            true,
            NULL,
            auth.uid(),
            'DELETE',
            'Position deleted - all permissions removed'
        );
        
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Create audit trigger for position_permissions
CREATE OR REPLACE FUNCTION audit_position_permissions_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO position_permissions_audit (
            position_id, app_function_id, permission_type_id, 
            old_value, new_value, changed_by, change_type
        ) VALUES (
            NEW.position_id, NEW.app_function_id, NEW.permission_type_id,
            NULL, NEW.is_granted, NEW.granted_by, 'INSERT'
        );
        RETURN NEW;
        
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.is_granted != NEW.is_granted THEN
            INSERT INTO position_permissions_audit (
                position_id, app_function_id, permission_type_id,
                old_value, new_value, changed_by, change_type
            ) VALUES (
                NEW.position_id, NEW.app_function_id, NEW.permission_type_id,
                OLD.is_granted, NEW.is_granted, NEW.granted_by, 'UPDATE'
            );
        END IF;
        RETURN NEW;
        
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO position_permissions_audit (
            position_id, app_function_id, permission_type_id,
            old_value, new_value, changed_by, change_type
        ) VALUES (
            OLD.position_id, OLD.app_function_id, OLD.permission_type_id,
            OLD.is_granted, NULL, auth.uid(), 'DELETE'
        );
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Create triggers
CREATE TRIGGER audit_position_permissions_trigger
    AFTER INSERT OR UPDATE OR DELETE ON position_permissions
    FOR EACH ROW EXECUTE FUNCTION audit_position_permissions_changes();

-- Update the existing trigger (if it exists)
DROP TRIGGER IF EXISTS sync_roles_on_position_changes ON hr_positions;
CREATE TRIGGER sync_roles_on_position_changes
    AFTER INSERT OR UPDATE OR DELETE ON hr_positions
    FOR EACH ROW EXECUTE FUNCTION sync_user_roles_from_positions();

-- 10. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_position_permissions_position_id ON position_permissions(position_id);
CREATE INDEX IF NOT EXISTS idx_position_permissions_app_function_id ON position_permissions(app_function_id);
CREATE INDEX IF NOT EXISTS idx_position_permissions_permission_type_id ON position_permissions(permission_type_id);
CREATE INDEX IF NOT EXISTS idx_position_permissions_is_granted ON position_permissions(is_granted);

-- 11. Create view for easy position permissions management
CREATE OR REPLACE VIEW position_permissions_view AS
SELECT 
    pp.id as permission_id,
    p.id as position_id,
    p.position_title_en,
    p.position_title_ar,
    af.id as app_function_id,
    af.function_name_en,
    af.function_name_ar,
    af.function_code,
    af.module_category,
    pt.id as permission_type_id,
    pt.permission_code,
    pt.permission_name_en,
    pt.permission_name_ar,
    pp.is_granted,
    pp.granted_by,
    pp.granted_at,
    pp.updated_at
FROM hr_positions p
CROSS JOIN app_functions af
CROSS JOIN permission_types pt
LEFT JOIN position_permissions pp ON (
    pp.position_id = p.id 
    AND pp.app_function_id = af.id 
    AND pp.permission_type_id = pt.id
)
WHERE p.is_active = true 
    AND af.is_active = true 
    AND pt.is_active = true
ORDER BY p.position_title_en, af.module_category, af.display_order, pt.display_order;

-- 12. Create RLS policies
ALTER TABLE app_functions ENABLE ROW LEVEL SECURITY;
ALTER TABLE permission_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE position_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE position_permissions_audit ENABLE ROW LEVEL SECURITY;

-- Allow read access to app_functions and permission_types for authenticated users
CREATE POLICY "Allow read access to app_functions" ON app_functions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow read access to permission_types" ON permission_types FOR SELECT TO authenticated USING (true);

-- Position permissions policies (restrict based on user role)
CREATE POLICY "Allow full access to position_permissions for admin users" ON position_permissions 
    FOR ALL TO authenticated 
    USING (auth.jwt() ->> 'role' IN ('admin', 'master_admin'))
    WITH CHECK (auth.jwt() ->> 'role' IN ('admin', 'master_admin'));

CREATE POLICY "Allow read access to position_permissions for all users" ON position_permissions 
    FOR SELECT TO authenticated USING (true);

-- Audit trail - read-only for admin users
CREATE POLICY "Allow read access to audit trail" ON position_permissions_audit 
    FOR SELECT TO authenticated 
    USING (auth.jwt() ->> 'role' IN ('admin', 'master_admin'));

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT ON app_functions TO authenticated;
GRANT SELECT ON permission_types TO authenticated;
GRANT ALL ON position_permissions TO authenticated;
GRANT SELECT ON position_permissions_audit TO authenticated;
GRANT SELECT ON position_permissions_view TO authenticated;

COMMENT ON TABLE app_functions IS 'System functions/modules that can have permissions assigned';
COMMENT ON TABLE permission_types IS 'Types of permissions (view, add, edit, update, delete)';
COMMENT ON TABLE position_permissions IS 'Permission matrix linking positions to functions and permission types';
COMMENT ON TABLE position_permissions_audit IS 'Audit trail for all permission changes';
COMMENT ON VIEW position_permissions_view IS 'Comprehensive view for position permissions management';