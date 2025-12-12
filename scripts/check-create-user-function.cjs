const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function checkCreateUserFunction() {
  console.log('🔍 Testing create_user function...\n');

  // Test with dummy data
  const { data, error } = await supabase.rpc('create_user', {
    p_username: 'test_check_function_' + Date.now(),
    p_password: 'TestPassword123!',
    p_is_master_admin: false,
    p_is_admin: false,
    p_user_type: 'branch_specific',
    p_branch_id: null,
    p_employee_id: null,
    p_position_id: null,
    p_quick_access_code: null
  });

  if (error) {
    console.log('❌ create_user function error:', error.message);
    console.log('Error code:', error.code);
    console.log('\n⚠️  Function needs to be created/updated with new parameters');
  } else {
    console.log('✅ create_user function exists and works');
    console.log('Response:', data);
  }
}

checkCreateUserFunction().catch(console.error);
