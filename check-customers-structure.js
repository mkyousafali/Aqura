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

async function checkCustomersTable() {
  console.log('📊 Customers Table Structure\n');
  console.log('='.repeat(60));
  
  const { data, error, count } = await supabase
    .from('customers')
    .select('*', { count: 'exact' })
    .limit(1);

  if (error) {
    console.error(`❌ Error: ${error.message}`);
    return;
  }

  console.log(`Total customers: ${count}\n`);
  
  if (data && data.length > 0) {
    const columns = Object.keys(data[0]);
    console.log('📋 All Columns:');
    columns.forEach(col => {
      const value = data[0][col];
      const type = value === null ? 'null' : typeof value;
      console.log(`  • ${col.padEnd(30)} (${type})`);
    });
    
    console.log('\n📍 Location/Address Columns:');
    const addressColumns = columns.filter(col => 
      col.includes('location') || col.includes('address') || col.includes('lat') || col.includes('lng')
    );
    addressColumns.forEach(col => {
      console.log(`  ✓ ${col}`);
    });
    
    console.log('\n📦 Sample Record:');
    console.log(JSON.stringify(data[0], null, 2));
  }
}

checkCustomersTable();
