// Script to check actual database functions using service role key
import { createClient } from '@supabase/supabase-js';

// Hardcoded values from .env file
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

if (!supabaseServiceKey) {
    console.error('❌ VITE_SUPABASE_SERVICE_ROLE_KEY not found in environment variables');
    process.exit(1);
}

// Create Supabase client with service role key
const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkDatabaseFunctions() {
    console.log('🔍 Checking database functions using service role key...\n');
    console.log('🔑 Using Supabase URL:', supabaseUrl);
    console.log('🔑 Service Role Key (first 20 chars):', supabaseServiceKey.substring(0, 20) + '...\n');

    try {
        // Query to get all functions from information_schema
        const { data: functions, error: functionsError } = await supabase
            .from('information_schema.routines')
            .select(`
                routine_name,
                routine_type,
                routine_schema,
                routine_definition,
                data_type,
                is_deterministic,
                routine_comment
            `)
            .eq('routine_schema', 'public')
            .eq('routine_type', 'FUNCTION')
            .order('routine_name');

        if (functionsError) {
            console.error('❌ Error querying functions:', functionsError);
            
            // Try alternative approach - query pg_proc directly
            console.log('\n🔄 Trying alternative approach...');
            
            const { data: pgFunctions, error: pgError } = await supabase.rpc('pg_get_functiondef', {
                funcid: 'test'
            });
            
            if (pgError) {
                console.log('❌ Alternative approach also failed:', pgError);
                
                // Try querying pg_catalog.pg_proc
                console.log('\n🔄 Trying pg_catalog approach...');
                
                const { data: catalogFunctions, error: catalogError } = await supabase
                    .from('pg_catalog.pg_proc')
                    .select('proname, prosrc')
                    .limit(10);
                
                if (catalogError) {
                    console.log('❌ pg_catalog approach failed:', catalogError);
                } else {
                    console.log('✅ Found functions in pg_catalog:', catalogFunctions);
                }
            }
            return;
        }

        if (!functions || functions.length === 0) {
            console.log('⚠️  No custom functions found in the public schema');
            
            // Let's try to get all schemas and their functions
            console.log('\n🔍 Checking all schemas...');
            
            const { data: allFunctions, error: allError } = await supabase
                .from('information_schema.routines')
                .select(`
                    routine_name,
                    routine_type,
                    routine_schema
                `)
                .eq('routine_type', 'FUNCTION')
                .order('routine_schema, routine_name');
            
            if (allError) {
                console.error('❌ Error querying all functions:', allError);
            } else {
                console.log(`✅ Found ${allFunctions?.length || 0} total functions across all schemas:`);
                
                // Group by schema
                const bySchema = {};
                allFunctions?.forEach(func => {
                    if (!bySchema[func.routine_schema]) {
                        bySchema[func.routine_schema] = [];
                    }
                    bySchema[func.routine_schema].push(func.routine_name);
                });
                
                Object.keys(bySchema).forEach(schema => {
                    console.log(`\n📂 Schema: ${schema} (${bySchema[schema].length} functions)`);
                    bySchema[schema].forEach(name => {
                        console.log(`   • ${name}`);
                    });
                });
            }
            return;
        }

        console.log(`✅ Found ${functions.length} custom functions in public schema:\n`);
        
        functions.forEach((func, index) => {
            console.log(`${index + 1}. 📝 Function: ${func.routine_name}`);
            console.log(`   📋 Type: ${func.routine_type}`);
            console.log(`   📊 Return Type: ${func.data_type}`);
            console.log(`   🔒 Deterministic: ${func.is_deterministic}`);
            
            if (func.routine_comment) {
                console.log(`   💬 Comment: ${func.routine_comment}`);
            }
            
            if (func.routine_definition && func.routine_definition !== 'NULL') {
                console.log(`   📜 Definition: ${func.routine_definition.substring(0, 100)}...`);
            }
            console.log('');
        });

        // Also check for any RPC functions we can call
        console.log('\n🔧 Testing common RPC functions from codebase...\n');
        
        const rpcFunctions = [
            'get_users_with_employee_details',
            'search_tasks',
            'get_task_statistics',
            'create_scheduled_assignment',
            'create_recurring_assignment',
            'reassign_task',
            'get_assignments_with_deadlines',
            'submit_quick_task_completion',
            'get_overdue_tasks_without_reminders',
            'check_receiving_task_dependencies',
            'get_dependency_completion_photos',
            'reassign_receiving_task',
            'get_user_receiving_tasks_dashboard',
            'validate_task_completion_requirements',
            'process_clearance_certificate_generation',
            'get_tasks_for_receiving_record',
            'get_receiving_tasks_for_user',
            'get_receiving_task_statistics',
            'sync_erp_reference_for_receiving_record',
            'check_erp_sync_status_for_record',
            'create_user',
            'generate_salt',
            'hash_password',
            'generate_unique_quick_access_code',
            'is_quick_access_code_available'
        ];

        for (const funcName of rpcFunctions) {
            try {
                // Try to call the function with minimal parameters to see if it exists
                const { data, error } = await supabase.rpc(funcName, {});
                
                if (error) {
                    if (error.message.includes('function') && error.message.includes('does not exist')) {
                        console.log(`❌ ${funcName} - Does not exist`);
                    } else {
                        console.log(`✅ ${funcName} - Exists (error: ${error.message.substring(0, 50)}...)`);
                    }
                } else {
                    console.log(`✅ ${funcName} - Exists and callable`);
                }
            } catch (err) {
                console.log(`❌ ${funcName} - Error: ${err.message.substring(0, 50)}...`);
            }
        }

    } catch (error) {
        console.error('💥 Unexpected error:', error);
    }
}

// Run the check
checkDatabaseFunctions().then(() => {
    console.log('\n✨ Database function check completed!');
    process.exit(0);
}).catch(error => {
    console.error('💥 Script failed:', error);
    process.exit(1);
});