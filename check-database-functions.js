// Check all database functions in Supabase// Script to check actual database functions using service role key

import { readFileSync } from 'fs';import { createClient } from '@supabase/supabase-js';

import { createClient } from '@supabase/supabase-js';

// Hardcoded values from .env file

// Load environment variables from frontend/.envconst supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';

const envPath = './frontend/.env';const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const envContent = readFileSync(envPath, 'utf-8');

const envVars = {};if (!supabaseServiceKey) {

    console.error('❌ VITE_SUPABASE_SERVICE_ROLE_KEY not found in environment variables');

envContent.split('\n').forEach(line => {    process.exit(1);

  const trimmed = line.trim();}

  if (trimmed && !trimmed.startsWith('#')) {

    const match = trimmed.match(/^([^=]+)=(.*)$/);// Create Supabase client with service role key

    if (match) {const supabase = createClient(supabaseUrl, supabaseServiceKey);

      envVars[match[1].trim()] = match[2].trim();

    }async function checkDatabaseFunctions() {

  }    console.log('🔍 Checking database functions using service role key...\n');

});    console.log('🔑 Using Supabase URL:', supabaseUrl);

    console.log('🔑 Service Role Key (first 20 chars):', supabaseServiceKey.substring(0, 20) + '...\n');

const supabaseUrl = envVars.VITE_SUPABASE_URL;

const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;    try {

        // Query to get all functions from information_schema

const supabase = createClient(supabaseUrl, supabaseServiceKey);        const { data: functions, error: functionsError } = await supabase

            .from('information_schema.routines')

console.log('\n🔍 Fetching all database functions from Supabase...');            .select(`

console.log('='.repeat(80));                routine_name,

                routine_type,

// Get database functions                routine_schema,

const { data, error } = await supabase.rpc('get_database_functions');                routine_definition,

                data_type,

if (error) {                is_deterministic,

  console.error('❌ Error:', error.message);                routine_comment

  process.exit(1);            `)

}            .eq('routine_schema', 'public')

            .eq('routine_type', 'FUNCTION')

console.log(`\n✅ Found ${data.length} database functions\n`);            .order('routine_name');



// Group functions by category (based on naming convention)        if (functionsError) {

const categories = {            console.error('❌ Error querying functions:', functionsError);

  'Task Management': [],            

  'Receiving & Vendor': [],            // Try alternative approach - query pg_proc directly

  'User Management': [],            console.log('\n🔄 Trying alternative approach...');

  'Employee Management': [],            

  'Financial': [],            const { data: pgFunctions, error: pgError } = await supabase.rpc('pg_get_functiondef', {

  'Notification': [],                funcid: 'test'

  'Customer': [],            });

  'System': [],            

  'Miscellaneous': []            if (pgError) {

};                console.log('❌ Alternative approach also failed:', pgError);

                

data.forEach(func => {                // Try querying pg_catalog.pg_proc

  const name = func.function_name;                console.log('\n🔄 Trying pg_catalog approach...');

                  

  if (name.includes('task') || name.includes('assignment') || name.includes('quick_task')) {                const { data: catalogFunctions, error: catalogError } = await supabase

    categories['Task Management'].push(name);                    .from('pg_catalog.pg_proc')

  } else if (name.includes('receiving') || name.includes('vendor') || name.includes('visit')) {                    .select('proname, prosrc')

    categories['Receiving & Vendor'].push(name);                    .limit(10);

  } else if (name.includes('user') || name.includes('password') || name.includes('auth') || name.includes('role')) {                

    categories['User Management'].push(name);                if (catalogError) {

  } else if (name.includes('employee') || name.includes('hr')) {                    console.log('❌ pg_catalog approach failed:', catalogError);

    categories['Employee Management'].push(name);                } else {

  } else if (name.includes('bill') || name.includes('payment') || name.includes('fine') || name.includes('expense')) {                    console.log('✅ Found functions in pg_catalog:', catalogFunctions);

    categories['Financial'].push(name);                }

  } else if (name.includes('notification') || name.includes('push') || name.includes('reminder')) {            }

    categories['Notification'].push(name);            return;

  } else if (name.includes('customer')) {        }

    categories['Customer'].push(name);

  } else if (name.includes('http') || name.includes('system') || name.includes('database') || name.includes('sync') || name.includes('schema')) {        if (!functions || functions.length === 0) {

    categories['System'].push(name);            console.log('⚠️  No custom functions found in the public schema');

  } else {            

    categories['Miscellaneous'].push(name);            // Let's try to get all schemas and their functions

  }            console.log('\n🔍 Checking all schemas...');

});            

            const { data: allFunctions, error: allError } = await supabase

// Display by category                .from('information_schema.routines')

for (const [category, functions] of Object.entries(categories)) {                .select(`

  if (functions.length > 0) {                    routine_name,

    console.log(`\n📂 ${category} (${functions.length} functions):`);                    routine_type,

    console.log('-'.repeat(80));                    routine_schema

    functions.sort().forEach(func => {                `)

      console.log(`  - ${func}`);                .eq('routine_type', 'FUNCTION')

    });                .order('routine_schema, routine_name');

  }            

}            if (allError) {

                console.error('❌ Error querying all functions:', allError);

console.log('\n' + '='.repeat(80));            } else {

console.log(`📈 Total Functions: ${data.length}`);                console.log(`✅ Found ${allFunctions?.length || 0} total functions across all schemas:`);

console.log('\n✅ Check complete!\n');                

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