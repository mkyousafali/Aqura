// Deploy user permissions view
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

// Read environment variables from frontend
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
        console.log('📋 Deploying user permissions view...');
        
        // Read the SQL file
        const sql = fs.readFileSync('../55-user-permissions-view.sql', 'utf8');
        
        // Split into statements
        const statements = sql
            .split(';')
            .map(s => s.trim())
            .filter(s => s.length > 0 && !s.startsWith('--'));
        
        console.log(`📝 Executing ${statements.length} SQL statements...`);
        
        for (let i = 0; i < statements.length; i++) {
            const statement = statements[i];
            if (statement.trim()) {
                console.log(`⚡ Executing statement ${i + 1}/${statements.length}: ${statement.substring(0, 50)}...`);
                
                try {
                    // Use direct RPC call for DDL statements
                    const { error } = await supabase.rpc('exec_sql', { 
                        sql_query: statement + ';' 
                    });
                    
                    if (error) {
                        console.error(`❌ Error in statement ${i + 1}:`, error);
                        // Continue with other statements
                    } else {
                        console.log(`✅ Statement ${i + 1} executed successfully`);
                    }
                } catch (err) {
                    console.error(`❌ Exception in statement ${i + 1}:`, err);
                }
            }
        }
        
        // Test the view
        console.log('🧪 Testing the user permissions view...');
        const { data: viewData, error: viewError } = await supabase
            .from('user_permissions_view')
            .select('user_id, username, role_name, function_code, can_view')
            .limit(5);
        
        if (viewError) {
            console.error('❌ Error testing view:', viewError);
        } else {
            console.log('✅ View test successful!');
            console.log('📊 Sample permissions data:', viewData);
        }
        
        console.log('🎉 Deployment completed!');
        
    } catch (error) {
        console.error('❌ Deployment failed:', error);
        process.exit(1);
    }
}

deployView();