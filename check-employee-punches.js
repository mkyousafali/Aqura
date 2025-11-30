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

const supabaseUrl = envVars.PUBLIC_SUPABASE_URL;
const supabaseServiceKey = envVars.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkEmployeePunches() {
  // First, check table structure
  console.log('🔍 Checking table structure...\n');
  
  const { data: sampleData, error: sampleError } = await supabase
    .from('hr_fingerprint_transactions')
    .select('*')
    .limit(1);

  if (sampleError) {
    console.error('❌ Error:', sampleError.message);
    return;
  }

  if (sampleData && sampleData.length > 0) {
    console.log('📋 Table columns:', Object.keys(sampleData[0]));
    console.log('📋 Sample record:', JSON.stringify(sampleData[0], null, 2));
    console.log('\n');
  }

  // Now check for employee 11, branch 3 - get all records sorted by date+time
  console.log('🔍 Getting ALL punch records for Employee ID 11, Branch ID 3 (sorted by date + time)...\n');

  const { data, error } = await supabase
    .from('hr_fingerprint_transactions')
    .select('*')
    .eq('employee_id', '11')
    .eq('branch_id', 3)
    .order('date', { ascending: false })
    .order('time', { ascending: false });

  if (error) {
    console.error('❌ Error:', error.message);
    return;
  }

  if (!data || data.length === 0) {
    console.log('⚠️ No punch records found for Employee ID 11, Branch ID 3');
    return;
  }

  console.log(`✅ Found ${data.length} punch record(s):\n`);

  data.forEach((record, index) => {
    console.log(`📌 Record ${index + 1}:`);
    console.log(`   Date: ${record.date}`);
    console.log(`   Time (Original): ${record.time}`);
    
    // Convert time minus 3 hours and show in 12-hour format
    const dateTime = new Date(`${record.date}T${record.time}`);
    const minus3DateTime = new Date(dateTime.getTime() - (3 * 60 * 60 * 1000));
    
    const hours24 = minus3DateTime.getHours();
    const minutes = String(minus3DateTime.getMinutes()).padStart(2, '0');
    const seconds = String(minus3DateTime.getSeconds()).padStart(2, '0');
    const hours12 = hours24 % 12 || 12;
    const ampm = hours24 >= 12 ? 'PM' : 'AM';
    const dateStr = minus3DateTime.toISOString().split('T')[0];
    
    console.log(`   Time (-3hrs): ${hours24}:${minutes} (24hr) = ${hours12}:${minutes} ${ampm} (12hr)`);
    console.log(`   Status: ${record.status}`);
    console.log('');
  });

  // Also check total count for this employee/branch combo
  const { count } = await supabase
    .from('hr_fingerprint_transactions')
    .select('*', { count: 'exact', head: true })
    .eq('employee_id', '11')
    .eq('branch_id', 3);

  console.log(`📊 Total punch records for Employee 11, Branch 3: ${count}`);
}

checkEmployeePunches();
