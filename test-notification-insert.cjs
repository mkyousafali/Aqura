const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');

// Load environment variables
const envPath = './frontend/.env';
const envContent = fs.readFileSync(envPath, 'utf-8');
const envVars = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      envVars[match[1].trim()] = match[2].trim();
    }
  }
});

const supabase = createClient(
  envVars.VITE_SUPABASE_URL,
  envVars.VITE_SUPABASE_SERVICE_ROLE_KEY
);

(async () => {
  console.log('Testing notification insert as it would happen from trigger...\n');
  
  // Simulate what the trigger does
  const testCustomerId = '32b49ea8-0e6c-45ec-9c2c-6e2e95e003f7';
  const testOrderNumber = 'ORD-TEST-001';
  const testCustomerName = 'yousuf';
  const testTotalAmount = 100.00;
  
  console.log('Attempting to insert notification with basic fields (old trigger)...');
  const { data: data1, error: error1 } = await supabase
    .from('notifications')
    .insert({
      title: 'New Order Received',
      message: `Order ${testOrderNumber} from ${testCustomerName} - Total: ${testTotalAmount} SAR`,
      type: 'order_new',
      created_by: testCustomerId
    })
    .select();
  
  if (error1) {
    console.log('❌ ERROR with basic fields:', error1.message);
    console.log('   Code:', error1.code);
    console.log('   Details:', error1.details);
    console.log('   Hint:', error1.hint);
  } else {
    console.log('✅ SUCCESS with basic fields');
    console.log('   Inserted ID:', data1[0].id);
    
    // Clean up
    await supabase
      .from('notifications')
      .delete()
      .eq('id', data1[0].id);
  }
  
  console.log('\n' + '='.repeat(80) + '\n');
  
  console.log('Attempting to insert notification with all fields (new trigger)...');
  const { data: data2, error: error2 } = await supabase
    .from('notifications')
    .insert({
      title: 'New Order Received',
      message: `Order ${testOrderNumber} from ${testCustomerName} - Total: ${testTotalAmount} SAR`,
      type: 'order_new',
      created_by: testCustomerId,
      created_by_name: testCustomerName,
      created_by_role: 'Customer',
      priority: 'high',
      status: 'published',
      target_type: 'all_admins',
      target_roles: ['Admin', 'Master Admin', 'Operations Manager', 'Branch Manager'],
      sent_at: new Date().toISOString()
    })
    .select();
  
  if (error2) {
    console.log('❌ ERROR with all fields:', error2.message);
    console.log('   Code:', error2.code);
    console.log('   Details:', error2.details);
    console.log('   Hint:', error2.hint);
  } else {
    console.log('✅ SUCCESS with all fields');
    console.log('   Inserted ID:', data2[0].id);
    
    // Clean up
    await supabase
      .from('notifications')
      .delete()
      .eq('id', data2[0].id);
  }
  
  console.log('\n' + '='.repeat(80) + '\n');
  console.log('Testing with anon key (as customer would use)...\n');
  
  const supabaseAnon = createClient(
    envVars.VITE_SUPABASE_URL,
    envVars.VITE_SUPABASE_ANON_KEY
  );
  
  const { data: data3, error: error3 } = await supabaseAnon
    .from('notifications')
    .insert({
      title: 'New Order Received',
      message: `Order ${testOrderNumber} from ${testCustomerName}`,
      type: 'order_new',
      created_by: testCustomerId
    })
    .select();
  
  if (error3) {
    console.log('❌ ERROR with anon key:', error3.message);
    console.log('   Code:', error3.code);
    console.log('   This might be the actual issue!');
  } else {
    console.log('✅ SUCCESS with anon key');
  }
})();
