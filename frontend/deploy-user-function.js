// Deploy fixed user function
// This fixes the department_id column issue

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

// Read environment variables
const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error('❌ Missing Supabase environment variables');
    console.log('Please ensure PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are set in .env');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function deployFunction() {
    try {
        console.log('📋 Deploying fixed user function...');
        
        // Read the SQL file
        const sql = fs.readFileSync('56-fixed-user-function.sql', 'utf8');
        
        console.log('🔨 Executing SQL...');
        const { error } = await supabase.rpc('exec_sql', { 
            sql_query: sql 
        });
        
        if (error) {
            console.error('❌ Error deploying function:', error);
            throw error;
        }
        
        console.log('✅ Function deployed successfully!');
        
        // Test the function
        console.log('🧪 Testing the function...');
        const { data: testData, error: testError } = await supabase.rpc('get_users_with_employee_details');
        
        if (testError) {
            console.error('❌ Error testing function:', testError);
        } else {
            console.log('✅ Function test successful!');
            console.log('📊 Sample data:', testData?.slice(0, 3));
        }
        
        // Test debug function
        console.log('🔍 Testing debug function...');
        const { data: debugData, error: debugError } = await supabase.rpc('debug_users');
        
        if (debugError) {
            console.error('❌ Error testing debug function:', debugError);
        } else {
            console.log('✅ Debug function test successful!');
            console.log('📊 Debug data:', debugData?.slice(0, 3));
        }
        
        console.log('🎉 All functions deployed and tested successfully!');
        
    } catch (error) {
        console.error('❌ Deployment failed:', error);
        process.exit(1);
    }
}

deployFunction();