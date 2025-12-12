const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function checkFunction() {
  console.log('🔍 Checking create_customer_order function...\n');

  try {
    // Try to call the function with test data to see the error
    const testData = {
      p_customer_id: '00000000-0000-0000-0000-000000000000',
      p_branch_id: 1,
      p_fulfillment_method: 'delivery',
      p_payment_method: 'cash',
      p_location_data: {},
      p_items: []
    };

    const { data, error } = await supabase.rpc('create_customer_order', testData);

    if (error) {
      console.log('❌ Function error (this will show us what columns it uses):\n');
      console.log('Error message:', error.message);
      console.log('Error details:', error.details);
      console.log('Error hint:', error.hint);
      console.log('Error code:', error.code);
      
      // The error message should tell us about the role_type column issue
    } else {
      console.log('✅ Function executed (unexpected with test data)');
    }

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

checkFunction();
