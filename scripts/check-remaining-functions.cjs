const { createClient } = require('@supabase/supabase-js');

const url = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(url, serviceKey);

const functionsToCheck = [
  'check_receiving_task_dependencies',
  'complete_receiving_task',
  'complete_receiving_task_simple',
  'create_customer_registration',
  'debug_get_dependency_photos',
  'get_all_receiving_tasks',
  'get_completed_receiving_tasks',
  'get_dependency_completion_photos',
  'get_incomplete_receiving_tasks',
  'get_receiving_task_statistics',
  'get_receiving_tasks_for_user',
  'get_tasks_for_receiving_record',
  'get_user_receiving_tasks_dashboard',
  'has_order_management_access',
  'process_clearance_certificate_generation',
  'reassign_receiving_task',
  'request_new_access_code',
  'sync_all_missing_erp_references',
  'sync_all_pending_erp_references',
  'sync_erp_reference_for_receiving_record',
  'sync_erp_references_from_task_completions',
  'validate_task_completion_requirements',
  'verify_password'
];

async function checkFunction(functionName) {
  const query = `
    SELECT pg_get_functiondef(oid) as definition
    FROM pg_proc 
    WHERE proname = '${functionName}' 
    AND pronamespace = 'public'::regnamespace;
  `;
  
  const { data, error } = await supabase.rpc('exec_sql', { query });
  
  if (error) {
    console.log(`\n=== ${functionName} ===`);
    console.log('Error:', error.message);
    return;
  }
  
  if (!data || data.length === 0) {
    console.log(`\n=== ${functionName} ===`);
    console.log('Function not found');
    return;
  }
  
  const definition = data[0].definition;
  const hasRoleType = definition.includes('role_type');
  
  console.log(`\n=== ${functionName} ===`);
  console.log(`Has role_type: ${hasRoleType}`);
  
  if (hasRoleType) {
    // Check if it's from receiving_tasks or users
    const receivingTasksRoleType = /receiving_tasks.*role_type|role_type.*receiving_tasks|rt\.role_type/i.test(definition);
    const usersRoleType = /users.*role_type|role_type.*users|u\.role_type/i.test(definition);
    
    console.log(`  - From receiving_tasks: ${receivingTasksRoleType}`);
    console.log(`  - From users: ${usersRoleType}`);
    
    // Show relevant snippets
    const lines = definition.split('\n');
    const roleTypeLines = lines.filter(line => line.toLowerCase().includes('role_type'));
    if (roleTypeLines.length > 0) {
      console.log('  Relevant lines:');
      roleTypeLines.forEach(line => {
        console.log(`    ${line.trim()}`);
      });
    }
  }
}

async function main() {
  console.log('Checking remaining functions for role_type usage...\n');
  
  for (const func of functionsToCheck) {
    await checkFunction(func);
  }
  
  console.log('\n\nDone!');
}

main();
