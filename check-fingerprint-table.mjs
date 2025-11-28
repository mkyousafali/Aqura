import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

// Load environment variables
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

async function checkFingerprint() {
  console.log('Checking hr_fingerprint_transactions table...\n');

  // Check total count
  const { data, error, count } = await supabase
    .from('hr_fingerprint_transactions')
    .select('*', { count: 'exact', head: false })
    .limit(5);

  if (error) {
    console.error('❌ Error:', error.message);
    return;
  }

  console.log(`📊 Total records: ${count}`);
  
  if (count === 0) {
    console.log('\n❌ Table is EMPTY!');
    console.log('\nPossible causes:');
    console.log('1. RLS policies blocking inserts');
    console.log('2. Data type mismatches');
    console.log('3. Constraint violations');
    console.log('4. Wrong table name in sync code');
    
    // Check table structure
    const { data: tableInfo, error: structError } = await supabase
      .rpc('get_table_columns', { table_name: 'hr_fingerprint_transactions' })
      .limit(1);
      
    console.log('\n📋 Checking table structure...');
  } else {
    console.log('\n✅ Sample records:');
    data.forEach((record, i) => {
      console.log(`\nRecord ${i + 1}:`);
      console.log('  Employee ID:', record.employee_id);
      console.log('  Date:', record.date);
      console.log('  Time:', record.time);
      console.log('  Status:', record.status);
      console.log('  Device:', record.device_id);
    });
  }
}

checkFingerprint();
