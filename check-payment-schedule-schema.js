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

async function checkPaymentScheduleSchema() {
  console.log('📊 Checking vendor_payment_schedule table structure...\n');
  
  const { data, error, count } = await supabase
    .from('vendor_payment_schedule')
    .select('*', { count: 'exact' })
    .limit(2);

  if (error) {
    console.error(`❌ Error: ${error.message}`);
    return;
  }

  console.log(`📊 Table: vendor_payment_schedule`);
  console.log(`   Total records: ${count}`);
  
  if (data && data.length > 0) {
    console.log(`   Columns:`, Object.keys(data[0]));
    console.log(`\n   Sample record:`, JSON.stringify(data[0], null, 2));
  } else {
    console.log('   No records found');
  }
  
  // Check if pr_excel_verified column exists
  if (data && data.length > 0) {
    const hasVerifiedColumn = 'pr_excel_verified' in data[0];
    console.log(`\n✅ pr_excel_verified column exists: ${hasVerifiedColumn}`);
  }
  
  // Try to query with the specific receiving_record_id
  console.log('\n\n🔍 Testing query with receiving_record_id...\n');
  const { data: testData, error: testError } = await supabase
    .from('vendor_payment_schedule')
    .select('pr_excel_verified')
    .eq('receiving_record_id', '0c8e30dd-3e92-49fb-8d4a-d12c58d37094');
  
  if (testError) {
    console.error(`❌ Query error: ${testError.message}`);
  } else {
    console.log(`✅ Query successful:`, testData);
  }
}

checkPaymentScheduleSchema().catch(console.error);
