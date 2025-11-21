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
  console.log('Checking orders table columns...\n');
  
  const { data: ordersColumns, error: ordersError } = await supabase
    .from('orders')
    .select('*')
    .limit(0);
  
  if (ordersError) {
    console.error('Orders table error:', ordersError.message);
  }
  
  console.log('Checking order_items table columns...\n');
  
  const { data: itemsColumns, error: itemsError } = await supabase
    .from('order_items')
    .select('*')
    .limit(0);
  
  if (itemsError) {
    console.error('Order_items table error:', itemsError.message);
  }
  
  // Now let's try to look at the create_customer_order function definition
  console.log('\nChecking create_customer_order function...\n');
  
  const { data: funcData, error: funcError } = await supabase.rpc('exec_sql', {
    sql_query: `
      SELECT pg_get_functiondef(oid) as definition
      FROM pg_proc
      WHERE proname = 'create_customer_order';
    `
  });
  
  if (funcError) {
    console.error('Function check error:', funcError);
  } else if (funcData && funcData.length > 0) {
    console.log('Function definition:');
    console.log(funcData[0].definition);
  }
})();
