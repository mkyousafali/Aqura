const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function checkExistingObjects() {
  console.log('🔍 Checking existing database objects...\n');

  // Check for set_user_context function
  console.log('1. Checking set_user_context function(s):');
  const { data: functions, error: funcError } = await supabase.rpc('exec_sql', {
    sql: `
      SELECT 
        p.proname as function_name,
        pg_get_function_arguments(p.oid) as arguments,
        pg_get_function_result(p.oid) as return_type
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE n.nspname = 'public' 
        AND p.proname = 'set_user_context'
      ORDER BY p.oid;
    `
  });

  if (funcError) {
    console.log('   ⚠️  Cannot query functions directly, trying alternative method...');
    // Try to call the function to see if it exists
    const { error: testError } = await supabase.rpc('set_user_context', {
      user_id: '00000000-0000-0000-0000-000000000000',
      role_type: 'test'
    });
    if (testError) {
      console.log(`   Error: ${testError.message}`);
    } else {
      console.log('   ✓ set_user_context exists (old signature with role_type)');
    }
  } else {
    console.log('   Functions found:', functions);
  }

  // Check for user_permissions_view
  console.log('\n2. Checking user_permissions_view:');
  const { data: viewData, error: viewError } = await supabase
    .from('user_permissions_view')
    .select('*')
    .limit(1);

  if (viewError) {
    console.log(`   ✗ View does not exist or error: ${viewError.message}`);
  } else {
    console.log(`   ✓ View exists, sample columns:`, Object.keys(viewData[0] || {}));
  }

  // Check for helper functions
  console.log('\n3. Checking helper functions:');
  const helperFunctions = [
    'is_user_admin',
    'is_user_master_admin', 
    'get_current_user_id',
    'current_user_is_admin'
  ];

  for (const funcName of helperFunctions) {
    const { error } = await supabase.rpc(funcName).limit(1);
    if (error) {
      console.log(`   ✗ ${funcName}: ${error.message}`);
    } else {
      console.log(`   ✓ ${funcName}: exists`);
    }
  }

  // Check users table columns
  console.log('\n4. Checking users table columns:');
  const { data: users, error: usersError } = await supabase
    .from('users')
    .select('id, username, is_master_admin, is_admin')
    .limit(1);

  if (usersError) {
    console.log(`   ✗ Error: ${usersError.message}`);
  } else {
    console.log(`   ✓ Columns exist:`, Object.keys(users[0] || {}));
  }

  console.log('\n✅ Check complete');
}

checkExistingObjects().catch(console.error);
