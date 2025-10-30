import fs from 'fs';
import path from 'path';

// Load the enhanced schema data
const schemaPath = path.join(process.cwd(), 'DATABASE_SCHEMA_REFERENCE_ENHANCED.json');
const schemaData = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));

// Migration directories
const migrationsDir = path.join(process.cwd(), 'migrations');
const tablesDir = path.join(migrationsDir, 'tables');
const functionsDir = path.join(migrationsDir, 'functions');
const triggersDir = path.join(migrationsDir, 'triggers');
const storageDir = path.join(migrationsDir, 'storage');
const policiesDir = path.join(migrationsDir, 'policies');
const viewsDir = path.join(migrationsDir, 'views');

// Data type mapping from JavaScript to PostgreSQL
const typeMapping = {
    'string': 'TEXT',
    'number': 'NUMERIC',
    'boolean': 'BOOLEAN',
    'object': 'JSONB'
};

// Common UUID fields that should be UUID type
const uuidFields = ['id', 'user_id', 'employee_id', 'task_id', 'assignment_id', 'branch_id', 'department_id', 'issued_by', 'acknowledged_by', 'resolved_by', 'deleted_by'];

// Common timestamp fields
const timestampFields = ['created_at', 'updated_at', 'issued_at', 'acknowledged_at', 'resolved_at', 'deleted_at', 'due_date', 'paid_date', 'follow_up_date'];

function inferPostgreSQLType(columnName, sampleValue, inferredType) {
    // UUID fields
    if (uuidFields.includes(columnName)) {
        return 'UUID';
    }
    
    // Timestamp fields
    if (timestampFields.includes(columnName)) {
        return 'TIMESTAMPTZ';
    }
    
    // Special field mappings
    if (columnName.includes('email')) return 'VARCHAR(255)';
    if (columnName.includes('phone')) return 'VARCHAR(20)';
    if (columnName.includes('code')) return 'VARCHAR(50)';
    if (columnName.includes('status')) return 'VARCHAR(50)';
    if (columnName.includes('type')) return 'VARCHAR(50)';
    if (columnName.includes('currency')) return 'VARCHAR(3)';
    if (columnName.includes('language')) return 'VARCHAR(10)';
    if (columnName.includes('reference')) return 'VARCHAR(100)';
    if (columnName.includes('url')) return 'TEXT';
    if (columnName.includes('amount') || columnName.includes('rate') || columnName.includes('salary')) return 'DECIMAL(12,2)';
    if (columnName.includes('percentage') || columnName.includes('completion_rate')) return 'DECIMAL(5,2)';
    
    // Check sample value patterns
    if (typeof sampleValue === 'string') {
        // UUID pattern
        if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(sampleValue)) {
            return 'UUID';
        }
        // Timestamp pattern
        if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(sampleValue)) {
            return 'TIMESTAMPTZ';
        }
        // Date pattern
        if (/^\d{4}-\d{2}-\d{2}$/.test(sampleValue)) {
            return 'DATE';
        }
        // Short strings
        if (sampleValue.length <= 50) {
            return 'VARCHAR(255)';
        }
        // Longer text
        return 'TEXT';
    }
    
    // Use basic type mapping
    return typeMapping[inferredType] || 'TEXT';
}

function generateTableMigration(tableName, tableData) {
    let sql = `-- Migration for table: ${tableName}\n`;
    sql += `-- Generated on: ${new Date().toISOString()}\n\n`;
    
    if (tableData.access_error || tableData.enhancement_error || !tableData.columns) {
        sql += `-- Note: Limited access to table schema\n`;
        sql += `-- This is a basic table structure based on available information\n\n`;
        
        sql += `CREATE TABLE IF NOT EXISTS public.${tableName} (\n`;
        sql += `    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\n`;
        sql += `    created_at TIMESTAMPTZ DEFAULT now(),\n`;
        sql += `    updated_at TIMESTAMPTZ DEFAULT now()\n`;
        sql += `);\n\n`;
        
        sql += `-- Enable Row Level Security\n`;
        sql += `ALTER TABLE public.${tableName} ENABLE ROW LEVEL SECURITY;\n\n`;
        
        sql += `-- Add updated_at trigger\n`;
        sql += `CREATE TRIGGER set_${tableName}_updated_at\n`;
        sql += `    BEFORE UPDATE ON public.${tableName}\n`;
        sql += `    FOR EACH ROW\n`;
        sql += `    EXECUTE FUNCTION public.set_updated_at();\n\n`;
        
        return sql;
    }
    
    sql += `CREATE TABLE IF NOT EXISTS public.${tableName} (\n`;
    
    const columns = tableData.columns;
    const columnDefinitions = [];
    
    columns.forEach((col, index) => {
        const columnName = col.name;
        const pgType = inferPostgreSQLType(columnName, col.sample_value, col.inferred_type);
        const isNullable = col.is_null ? '' : ' NOT NULL';
        
        let columnDef = `    ${columnName} ${pgType}`;
        
        // Add constraints for common patterns
        if (columnName === 'id') {
            columnDef += ' PRIMARY KEY DEFAULT gen_random_uuid()';
        } else if (columnName.includes('email')) {
            columnDef += ' UNIQUE';
        } else if (columnName === 'created_at' || columnName === 'updated_at') {
            columnDef += ' DEFAULT now()';
        } else if (pgType === 'BOOLEAN') {
            if (col.sample_value === false) {
                columnDef += ' DEFAULT false';
            } else if (col.sample_value === true) {
                columnDef += ' DEFAULT true';
            }
        }
        
        columnDef += isNullable;
        columnDefinitions.push(columnDef);
    });
    
    sql += columnDefinitions.join(',\n');
    sql += '\n);\n\n';
    
    // Add indexes for common patterns
    const indexableFields = columns.filter(col => 
        uuidFields.includes(col.name) && col.name !== 'id' ||
        col.name.includes('status') ||
        col.name.includes('type') ||
        timestampFields.includes(col.name)
    );
    
    indexableFields.forEach(col => {
        sql += `CREATE INDEX IF NOT EXISTS idx_${tableName}_${col.name} ON public.${tableName}(${col.name});\n`;
    });
    
    if (indexableFields.length > 0) sql += '\n';
    
    // Enable RLS
    sql += `-- Enable Row Level Security\n`;
    sql += `ALTER TABLE public.${tableName} ENABLE ROW LEVEL SECURITY;\n\n`;
    
    // Add updated_at trigger if the table has updated_at
    if (columns.some(col => col.name === 'updated_at')) {
        sql += `-- Add updated_at trigger\n`;
        sql += `CREATE TRIGGER set_${tableName}_updated_at\n`;
        sql += `    BEFORE UPDATE ON public.${tableName}\n`;
        sql += `    FOR EACH ROW\n`;
        sql += `    EXECUTE FUNCTION public.set_updated_at();\n\n`;
    }
    
    // Add comments
    sql += `-- Table comments\n`;
    sql += `COMMENT ON TABLE public.${tableName} IS 'Generated from Aqura schema analysis';\n`;
    
    return sql;
}

function generateStorageMigration() {
    let sql = `-- Storage Buckets Migration\n`;
    sql += `-- Generated on: ${new Date().toISOString()}\n\n`;
    
    Object.entries(schemaData.storageBuckets).forEach(([bucketName, bucket]) => {
        sql += `-- Create storage bucket: ${bucketName}\n`;
        sql += `INSERT INTO storage.buckets (id, name, public, created_at, updated_at)\n`;
        sql += `VALUES ('${bucket.id}', '${bucketName}', ${bucket.public}, '${bucket.created_at}', '${bucket.updated_at}')\n`;
        sql += `ON CONFLICT (id) DO NOTHING;\n\n`;
        
        // Add basic RLS policies for storage
        sql += `-- Storage policies for ${bucketName}\n`;
        sql += `CREATE POLICY "Authenticated users can view ${bucketName}" ON storage.objects\n`;
        sql += `    FOR SELECT TO authenticated\n`;
        sql += `    USING (bucket_id = '${bucketName}');\n\n`;
        
        sql += `CREATE POLICY "Authenticated users can upload to ${bucketName}" ON storage.objects\n`;
        sql += `    FOR INSERT TO authenticated\n`;
        sql += `    WITH CHECK (bucket_id = '${bucketName}');\n\n`;
    });
    
    return sql;
}

function generateCommonFunctions() {
    return `-- Common Database Functions
-- Generated on: ${new Date().toISOString()}

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate notification reference
CREATE OR REPLACE FUNCTION public.generate_notification_reference()
RETURNS TEXT AS $$
BEGIN
    RETURN 'NOT-' || to_char(now(), 'YYYYMMDD') || '-' || 
           LPAD(nextval('notification_sequence')::text, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- Function to generate warning reference
CREATE OR REPLACE FUNCTION public.generate_warning_reference()
RETURNS TEXT AS $$
BEGIN
    RETURN 'WRN-' || to_char(now(), 'YYYYMMDD') || '-' || 
           LPAD(nextval('warning_sequence')::text, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- Function to generate task reference
CREATE OR REPLACE FUNCTION public.generate_task_reference()
RETURNS TEXT AS $$
BEGIN
    RETURN 'TSK-' || to_char(now(), 'YYYYMMDD') || '-' || 
           LPAD(nextval('task_sequence')::text, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- Create sequences for reference generators
CREATE SEQUENCE IF NOT EXISTS notification_sequence START 1;
CREATE SEQUENCE IF NOT EXISTS warning_sequence START 1;
CREATE SEQUENCE IF NOT EXISTS task_sequence START 1;

-- Function to check user permissions
CREATE OR REPLACE FUNCTION public.check_user_permission(
    user_uuid UUID,
    permission_name TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM user_roles ur
        JOIN role_permissions rp ON ur.role_id = rp.role_id
        WHERE ur.user_id = user_uuid 
        AND rp.permission = permission_name
        AND ur.is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user branch
CREATE OR REPLACE FUNCTION public.get_user_branch(user_uuid UUID)
RETURNS UUID AS $$
DECLARE
    branch_uuid UUID;
BEGIN
    SELECT he.branch_id INTO branch_uuid
    FROM hr_employees he
    JOIN users u ON u.employee_id = he.id
    WHERE u.id = user_uuid;
    
    RETURN branch_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
`;
}

function generateBasicPolicies() {
    return `-- Basic RLS Policies Template
-- Generated on: ${new Date().toISOString()}

-- Users can view their own records
CREATE POLICY "Users can view own records" ON public.users
    FOR SELECT TO authenticated
    USING (auth.uid() = id);

-- Users can update their own records
CREATE POLICY "Users can update own records" ON public.users
    FOR UPDATE TO authenticated
    USING (auth.uid() = id);

-- Employees can view their own HR records
CREATE POLICY "Employees can view own HR records" ON public.hr_employees
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND employee_id = hr_employees.id
        )
    );

-- Task assignments visibility
CREATE POLICY "Users can view assigned tasks" ON public.task_assignments
    FOR SELECT TO authenticated
    USING (assigned_to = auth.uid());

-- Quick task assignments visibility
CREATE POLICY "Users can view assigned quick tasks" ON public.quick_task_assignments
    FOR SELECT TO authenticated
    USING (assigned_to = auth.uid());

-- Warning visibility
CREATE POLICY "Users can view their warnings" ON public.employee_warnings
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND employee_id = employee_warnings.employee_id
        )
    );

-- Notification visibility
CREATE POLICY "Users can view their notifications" ON public.notifications
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM notification_recipients nr
            WHERE nr.notification_id = notifications.id
            AND nr.user_id = auth.uid()
        )
    );
`;
}

function generateMasterMigration(tableNames) {
    let sql = `-- Master Migration Script for Aqura Database
-- Generated on: ${new Date().toISOString()}
-- This script creates the complete database structure

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_crypt";

-- Run in sequence:
-- 1. Common functions
\\i functions/common_functions.sql

-- 2. Create tables (in dependency order)
`;

    // Group tables by dependency (rough estimation)
    const coreTables = ['users', 'branches', 'hr_departments', 'hr_positions', 'hr_levels'];
    const dependentTables = tableNames.filter(name => !coreTables.includes(name));
    
    [...coreTables, ...dependentTables].forEach(tableName => {
        sql += `\\i tables/${tableName}.sql\n`;
    });
    
    sql += `
-- 3. Create views
\\i views/user_management_view.sql
\\i views/active_warnings_view.sql
\\i views/active_fines_view.sql
\\i views/position_roles_view.sql
\\i views/user_permissions_view.sql

-- 4. Setup storage buckets
\\i storage/storage_buckets.sql

-- 5. Apply RLS policies
\\i policies/basic_policies.sql

-- 6. Create triggers (if any specific ones needed)

-- Final steps
-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Update table statistics
ANALYZE;

-- Success message
SELECT 'Aqura database migration completed successfully!' as status;
`;
    
    return sql;
}

async function generateAllMigrations() {
    console.log('🚀 Generating migration files...\n');
    
    const tables = schemaData.tables;
    const tableNames = Object.keys(tables);
    
    // 1. Generate table migrations
    console.log('📋 Creating table migrations...');
    for (const [tableName, tableData] of Object.entries(tables)) {
        const sql = generateTableMigration(tableName, tableData);
        const filename = path.join(tablesDir, `${tableName}.sql`);
        fs.writeFileSync(filename, sql);
        console.log(`  ✅ ${tableName}.sql`);
    }
    
    // 2. Generate common functions
    console.log('\n🔧 Creating function migrations...');
    const commonFunctionsSQL = generateCommonFunctions();
    fs.writeFileSync(path.join(functionsDir, 'common_functions.sql'), commonFunctionsSQL);
    console.log('  ✅ common_functions.sql');
    
    // 3. Generate storage migration
    console.log('\n🪣 Creating storage migrations...');
    const storageSQL = generateStorageMigration();
    fs.writeFileSync(path.join(storageDir, 'storage_buckets.sql'), storageSQL);
    console.log('  ✅ storage_buckets.sql');
    
    // 4. Generate basic policies
    console.log('\n🔒 Creating policy migrations...');
    const policiesSQL = generateBasicPolicies();
    fs.writeFileSync(path.join(policiesDir, 'basic_policies.sql'), policiesSQL);
    console.log('  ✅ basic_policies.sql');
    
    // 5. Generate views (based on known views from schema)
    console.log('\n👁️ Creating view migrations...');
    const knownViews = ['user_management_view', 'active_warnings_view', 'active_fines_view', 'position_roles_view', 'user_permissions_view'];
    
    knownViews.forEach(viewName => {
        const viewSQL = generateViewMigration(viewName);
        fs.writeFileSync(path.join(viewsDir, `${viewName}.sql`), viewSQL);
        console.log(`  ✅ ${viewName}.sql`);
    });
    
    // 6. Generate master migration
    console.log('\n📜 Creating master migration...');
    const masterSQL = generateMasterMigration(tableNames);
    fs.writeFileSync(path.join(migrationsDir, 'master_migration.sql'), masterSQL);
    console.log('  ✅ master_migration.sql');
    
    // 7. Create README
    console.log('\n📚 Creating migration documentation...');
    const readmeContent = generateMigrationReadme(tableNames);
    fs.writeFileSync(path.join(migrationsDir, 'README.md'), readmeContent);
    console.log('  ✅ README.md');
    
    console.log(`\n✅ Migration generation completed!`);
    console.log(`📁 Generated ${tableNames.length} table migrations`);
    console.log(`📁 Location: ${migrationsDir}`);
    console.log(`\n🚀 To run migrations:`);
    console.log(`   psql -d your_database -f migrations/master_migration.sql`);
}

function generateViewMigration(viewName) {
    const viewSQL = {
        'user_management_view': `-- User Management View
-- Combines user data with employee information
CREATE OR REPLACE VIEW public.user_management_view AS
SELECT 
    u.id as user_id,
    u.username,
    u.email,
    u.is_active,
    u.created_at as user_created_at,
    he.id as employee_id,
    he.employee_name,
    he.employee_code,
    hd.department_name,
    hp.position_title,
    b.branch_name
FROM public.users u
LEFT JOIN public.hr_employees he ON u.employee_id = he.id
LEFT JOIN public.hr_departments hd ON he.department_id = hd.id
LEFT JOIN public.hr_positions hp ON he.position_id = hp.id
LEFT JOIN public.branches b ON he.branch_id = b.id;`,

        'active_warnings_view': `-- Active Warnings View
-- Shows all active employee warnings with detailed information
CREATE OR REPLACE VIEW public.active_warnings_view AS
SELECT 
    ew.*,
    he.employee_name,
    he.employee_code,
    u.username as issued_by_user,
    b.branch_name
FROM public.employee_warnings ew
LEFT JOIN public.hr_employees he ON ew.employee_id = he.id
LEFT JOIN public.users u ON ew.issued_by = u.id
LEFT JOIN public.branches b ON ew.branch_id = b.id
WHERE ew.warning_status = 'active' 
AND ew.is_deleted = false;`,

        'active_fines_view': `-- Active Fines View
-- Shows all active fines from warnings
CREATE OR REPLACE VIEW public.active_fines_view AS
SELECT 
    ew.*,
    he.employee_name,
    he.employee_code
FROM public.employee_warnings ew
LEFT JOIN public.hr_employees he ON ew.employee_id = he.id
WHERE ew.has_fine = true 
AND ew.fine_status != 'paid'
AND ew.warning_status = 'active'
AND ew.is_deleted = false;`,

        'position_roles_view': `-- Position Roles View
-- Shows positions with their associated roles
CREATE OR REPLACE VIEW public.position_roles_view AS
SELECT 
    hp.id as position_id,
    hp.position_title,
    hp.department_id,
    hd.department_name,
    ur.role_id,
    r.role_name
FROM public.hr_positions hp
LEFT JOIN public.hr_departments hd ON hp.department_id = hd.id
LEFT JOIN public.user_roles ur ON hp.id = ur.position_id
LEFT JOIN public.roles r ON ur.role_id = r.id;`,

        'user_permissions_view': `-- User Permissions View
-- Shows all permissions for each user
CREATE OR REPLACE VIEW public.user_permissions_view AS
SELECT 
    u.id as user_id,
    u.username,
    ur.role_id,
    r.role_name,
    rp.permission,
    rp.resource
FROM public.users u
JOIN public.user_roles ur ON u.id = ur.user_id
JOIN public.roles r ON ur.role_id = r.id
JOIN public.role_permissions rp ON r.id = rp.role_id
WHERE ur.is_active = true;`
    };
    
    return viewSQL[viewName] || `-- View: ${viewName}\n-- TODO: Define view structure\n`;
}

function generateMigrationReadme(tableNames) {
    return `# Aqura Database Migrations

Generated on: ${new Date().toISOString()}

## Overview

This directory contains PostgreSQL migration files for the complete Aqura database structure.

## Directory Structure

\`\`\`
migrations/
├── master_migration.sql       # Main migration script (run this)
├── README.md                  # This file
├── tables/                    # Individual table creation scripts
│   ├── users.sql
│   ├── hr_employees.sql
│   └── ... (${tableNames.length} total tables)
├── functions/                 # Database functions
│   └── common_functions.sql
├── triggers/                  # Database triggers
├── storage/                   # Storage bucket setup
│   └── storage_buckets.sql
├── policies/                  # Row Level Security policies
│   └── basic_policies.sql
└── views/                     # Database views
    ├── user_management_view.sql
    └── ...
\`\`\`

## Quick Start

### Option 1: Run Complete Migration
\`\`\`bash
psql -d your_database_name -f migrations/master_migration.sql
\`\`\`

### Option 2: Run Individual Components
\`\`\`bash
# 1. Functions first
psql -d your_database_name -f migrations/functions/common_functions.sql

# 2. Core tables
psql -d your_database_name -f migrations/tables/users.sql
psql -d your_database_name -f migrations/tables/branches.sql
# ... continue with other tables

# 3. Views
psql -d your_database_name -f migrations/views/user_management_view.sql

# 4. Storage
psql -d your_database_name -f migrations/storage/storage_buckets.sql

# 5. Policies
psql -d your_database_name -f migrations/policies/basic_policies.sql
\`\`\`

## Generated Tables (${tableNames.length} total)

### HR Management Tables
- hr_employees, hr_departments, hr_positions, hr_levels
- hr_employee_contacts, hr_employee_documents, hr_employee_main_documents
- hr_position_assignments, hr_position_reporting_template
- hr_salary_components, hr_salary_wages
- hr_fingerprint_transactions, hr_document_categories_summary

### Task Management Tables
- tasks, task_assignments, task_completions, task_attachments, task_images
- quick_tasks, quick_task_assignments, quick_task_completions
- quick_task_comments, quick_task_files, quick_task_user_preferences
- quick_tasks_with_details, quick_task_files_with_details, quick_task_completion_details

### User Management Tables
- users, user_roles, user_sessions, user_device_sessions
- user_audit_logs, user_password_history, user_permissions_view, user_management_view

### Warning & Fine System
- employee_warnings, employee_warning_history, employee_fine_payments
- active_warnings_view, active_fines_view

### Notification System
- notifications, notification_queue, notification_recipients
- notification_read_states, notification_attachments, push_subscriptions

### Financial Management
- expense_parent_categories, expense_sub_categories, expense_requisitions, expense_scheduler
- vendors, vendor_payment_schedule, non_approved_payment_scheduler

### Receiving & Vendor Management
- receiving_records, receiving_tasks, receiving_records_pr_excel_status
- requesters

### System Configuration
- branches, app_functions, role_permissions
- recurring_assignment_schedules, recurring_schedule_check_log

## Storage Buckets

The following storage buckets will be created:
- employee-documents, user-avatars, documents
- original-bills, vendor-contracts, pr-excel-files
- requisition-images, expense-scheduler-bills
- notification-images, task-images, warning-documents
- quick-task-files, completion-photos, clearance-certificates

## Key Features

### Automatic Timestamps
- All tables include \`created_at\` and \`updated_at\` with automatic triggers

### UUID Primary Keys
- All tables use UUID primary keys with \`gen_random_uuid()\` default

### Row Level Security
- All tables have RLS enabled with basic policies

### Indexing
- Automatic indexes on foreign keys, status fields, and timestamps

### Reference Generation
- Functions for generating warning, task, and notification references

## Prerequisites

1. PostgreSQL 12+ with uuid-ossp extension
2. Supabase setup (if using Supabase features)
3. Proper database permissions

## Notes

- Generated from actual Aqura database schema analysis
- Includes sample data structures and inferred types
- RLS policies may need customization for your security requirements
- Some advanced triggers and functions may require manual implementation

## Support

This migration was auto-generated from the Aqura database schema.
Review and test in a development environment before running in production.
`;
}

// Run the migration generation
generateAllMigrations().catch(console.error);