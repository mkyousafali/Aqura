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

async function checkOrderTables() {
  console.log('🔍 Checking for order/cart related tables...\n');
  
  // Check for tables with order/cart/customer in name
  const tableNames = [
    'orders',
    'order_items',
    'cart',
    'cart_items',
    'customer_orders',
    'order_history',
    'customers',
    'customer_addresses',
    'customer_recovery_requests',
    'offers',
    'offer_usage_logs'
  ];

  for (const tableName of tableNames) {
    const { data, error, count } = await supabase
      .from(tableName)
      .select('*', { count: 'exact', head: true });

    if (error) {
      if (error.code === 'PGRST116') {
        console.log(`❌ Table '${tableName}' does NOT exist`);
      } else {
        console.log(`❌ Table '${tableName}': ${error.message}`);
      }
    } else {
      console.log(`✅ Table '${tableName}' EXISTS with ${count} records`);
      
      // Get column structure
      const { data: sampleData } = await supabase
        .from(tableName)
        .select('*')
        .limit(1);
      
      if (sampleData && sampleData.length > 0) {
        console.log(`   Columns:`, Object.keys(sampleData[0]).join(', '));
      }
    }
  }
}

checkOrderTables();
