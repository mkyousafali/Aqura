import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

// Load environment variables from frontend/.env
const envPath = './frontend/.env';
const envContent = readFileSync(envPath, 'utf-8');
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

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkTableStructure(tableName) {
  console.log(`\n📊 Table: ${tableName}`);
  console.log('='.repeat(60));
  
  const { data, error } = await supabase
    .from(tableName)
    .select('*')
    .limit(1);

  if (error) {
    console.log(`❌ Error: ${error.message}`);
    return;
  }

  if (data && data.length > 0) {
    const columns = Object.keys(data[0]);
    console.log('Columns:');
    columns.forEach(col => {
      console.log(`  - ${col}: ${typeof data[0][col]}`);
    });
    console.log('\nSample data:');
    console.log(JSON.stringify(data[0], null, 2));
  } else {
    // Get count to see if table has any records
    const { count } = await supabase.from(tableName).select('*', { count: 'exact', head: true });
    console.log(`Table exists but has ${count || 0} records`);
  }
}

async function main() {
  console.log('🔍 Checking Order/Cart Related Tables Schema\n');
  
  const tables = [
    'orders',
    'order_items', 
    'cart',
    'cart_items',
    'customer_orders',
    'order_history',
    'customer_addresses'
  ];

  for (const table of tables) {
    await checkTableStructure(table);
  }
}

main();
