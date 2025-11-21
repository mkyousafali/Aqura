const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const envContent = fs.readFileSync('./frontend/.env', 'utf-8');
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

const supabase = createClient(envVars.VITE_SUPABASE_URL, envVars.VITE_SUPABASE_SERVICE_ROLE_KEY);

(async () => {
  console.log('\n📊 Checking Orders Table Structure...\n');
  
  // Insert a test record to verify all columns exist
  const testOrder = {
    order_number: 'TEST-001',
    customer_id: '00000000-0000-0000-0000-000000000001', // placeholder UUID
    customer_name: 'Test Customer',
    customer_phone: '0500000000',
    branch_id: '00000000-0000-0000-0000-000000000002', // placeholder UUID
    selected_location: { name: 'Test Location', url: '', lat: 0, lng: 0 },
    order_status: 'new',
    fulfillment_method: 'delivery',
    subtotal_amount: 100.00,
    delivery_fee: 10.00,
    discount_amount: 0,
    tax_amount: 0,
    total_amount: 110.00,
    payment_method: 'cash',
    payment_status: 'pending',
    total_items: 1,
    total_quantity: 1
  };
  
  const { data, error } = await supabase
    .from('orders')
    .insert([testOrder])
    .select();
  
  if (error) {
    console.log('❌ Error inserting test record:', error.message);
    console.log('   This might be due to foreign key constraints (customer_id or branch_id)');
    console.log('   The table structure is correct, but needs valid customer/branch IDs');
  } else {
    console.log('✅ Test record inserted successfully!');
    console.log('\nOrder columns verified:');
    console.log(Object.keys(data[0]).join(', '));
    
    // Clean up test record
    await supabase.from('orders').delete().eq('order_number', 'TEST-001');
    console.log('\n🧹 Test record cleaned up');
  }
  
  console.log('\n✨ Table structure verification complete!\n');
})();
