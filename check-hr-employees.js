// Check hr_employees table count
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
      const key = match[1].trim();
      const value = match[2].trim();
      envVars[key] = value;
    }
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

console.log('🔗 Connecting to Supabase...');
console.log('URL:', supabaseUrl ? '✅ Found' : '❌ Missing');

const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Check hr_employees count
console.log('\n📊 Checking hr_employees table...');
const { count, error, data } = await supabase
  .from('hr_employees')
  .select('*', { count: 'exact' });

if (error) {
  console.error('❌ Error:', error.message);
  process.exit(1);
}

console.log('✅ Total hr_employees records:', count);

// Show sample data (first 5 records)
if (data && data.length > 0) {
  console.log('\n📋 Sample records (first 5):');
  data.slice(0, 5).forEach((emp, idx) => {
    console.log(`${idx + 1}. ID: ${emp.id}, Name: ${emp.first_name} ${emp.last_name}, Employee ID: ${emp.employee_id}`);
  });
}
