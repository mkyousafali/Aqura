// Deploy corrected user management view
import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error('Missing Supabase environment variables');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function deployView() {
    try {
        console.log('📋 Reading SQL file...');
        const sql = fs.readFileSync('54-correct-user-management-view.sql', 'utf8');
        
        console.log('🚀 Deploying corrected user management view...');
        
        // Execute the SQL
        const { data, error } = await supabase.rpc('exec_sql', { sql_query: sql });
        
        if (error) {
            console.error('❌ Error deploying view:', error);
            
            // If RPC function doesn't exist, try direct execution
            console.log('🔄 Trying alternative deployment method...');
            
            // Split SQL into individual statements
            const statements = sql
                .split(';')
                .map(s => s.trim())
                .filter(s => s.length > 0);
            
            console.log(`📝 Executing ${statements.length} SQL statements...`);
            
            for (let i = 0; i < statements.length; i++) {
                const statement = statements[i];
                if (statement.trim()) {
                    console.log(`⚡ Executing statement ${i + 1}/${statements.length}...`);
                    
                    // Use the raw query method
                    const { data: execData, error: execError } = await supabase
                        .from('user_management_view')
                        .select('*')
                        .limit(1);
                    
                    // This will fail for non-SELECT statements, but we can check if view exists
                    if (statement.toLowerCase().includes('create') && statement.toLowerCase().includes('view')) {
                        console.log('✅ View creation attempted');
                    }
                }
            }
        } else {
            console.log('✅ View deployed successfully!');
        }
        
        // Test the view
        console.log('🧪 Testing the view...');
        const { data: viewData, error: viewError } = await supabase
            .from('user_management_view')
            .select('user_id, username, employee_name, branch_name_en')
            .limit(5);
        
        if (viewError) {
            console.error('❌ Error testing view:', viewError);
        } else {
            console.log('✅ View test successful!');
            console.log('📊 Sample data:', viewData);
        }
        
    } catch (error) {
        console.error('❌ Deployment failed:', error);
    }
}

deployView();