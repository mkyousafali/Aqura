// Simple deployment script for user management view
// Run this in frontend environment: npm run deploy-view

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Read environment variables
const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error('❌ Missing Supabase environment variables');
    console.log('Please ensure PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are set in .env');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function deployView() {
    try {
        console.log('📋 Deploying user management view...');
        
        // Drop existing view first
        console.log('🗑️ Dropping existing view...');
        const { error: dropError } = await supabase.rpc('exec_sql', { 
            sql_query: 'DROP VIEW IF EXISTS user_management_view;' 
        });
        
        if (dropError && !dropError.message.includes('does not exist')) {
            console.log('⚠️ Warning dropping view:', dropError.message);
        }
        
        // Create the new view
        const createViewSQL = `
CREATE OR REPLACE VIEW user_management_view AS
SELECT 
    u.id,
    u.username,
    u.user_type,
    u.status,
    u.role_type,
    u.is_first_login,
    u.last_login_at as last_login,
    u.failed_login_attempts,
    u.created_at,
    u.updated_at,
    u.avatar,
    
    -- Employee details
    u.employee_id,
    e.employee_id as employee_code,
    e.name as employee_name,
    e.status as employee_status,
    e.hire_date,
    
    -- Branch details
    u.branch_id,
    b.name_en as branch_name,
    b.name_ar as branch_name_ar,
    b.location_en as branch_location_en,
    b.location_ar as branch_location_ar,
    b.is_active as branch_active,
    
    -- Position details
    u.position_id,
    p.position_title_en,
    p.position_title_ar,
    
    -- Department details
    d.id as department_id,
    d.department_name_en,
    d.department_name_ar
    
FROM users u
LEFT JOIN hr_employees e ON u.employee_id = e.id
LEFT JOIN branches b ON u.branch_id = b.id
LEFT JOIN hr_positions p ON u.position_id = p.id
LEFT JOIN hr_departments d ON p.department_id = d.id
ORDER BY u.username;
        `;
        
        console.log('🔨 Creating new view...');
        const { error: createError } = await supabase.rpc('exec_sql', { 
            sql_query: createViewSQL 
        });
        
        if (createError) {
            console.error('❌ Error creating view:', createError);
            throw createError;
        }
        
        console.log('✅ View created successfully!');
        
        // Grant permissions
        console.log('🔐 Setting permissions...');
        const grantSQL = `
GRANT SELECT ON user_management_view TO authenticated;
GRANT SELECT ON user_management_view TO anon;
        `;
        
        const { error: grantError } = await supabase.rpc('exec_sql', { 
            sql_query: grantSQL 
        });
        
        if (grantError) {
            console.log('⚠️ Warning setting permissions:', grantError.message);
        }
        
        // Test the view
        console.log('🧪 Testing the view...');
        const { data: viewData, error: viewError } = await supabase
            .from('user_management_view')
            .select('id, username, employee_name, branch_name')
            .limit(3);
        
        if (viewError) {
            console.error('❌ Error testing view:', viewError);
            throw viewError;
        }
        
        console.log('✅ View test successful!');
        console.log('📊 Sample data:', viewData);
        console.log('🎉 Deployment completed successfully!');
        
    } catch (error) {
        console.error('❌ Deployment failed:', error);
        process.exit(1);
    }
}

deployView();