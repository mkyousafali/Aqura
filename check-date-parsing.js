import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

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

// Get the specific payment
const { data, error } = await supabase
  .from('vendor_payment_schedule')
  .select('*')
  .eq('id', 'fa939cd4-f9d1-45e3-8f7b-e00ec4041f59')
  .single();

if (error) {
  console.error('Error:', error);
} else {
  console.log('\n📦 Payment Data from Database:');
  console.log('ID:', data.id);
  console.log('Vendor:', data.vendor_name);
  console.log('scheduled_date:', data.scheduled_date);
  console.log('due_date:', data.due_date);
  console.log('scheduled_date type:', typeof data.scheduled_date);
  
  console.log('\n🔍 Date Parsing Tests:');
  
  // Test 1: Parse scheduled_date as-is
  const date1 = new Date(data.scheduled_date);
  console.log('\n1. new Date(scheduled_date):');
  console.log('   Result:', date1);
  console.log('   ISO:', date1.toISOString());
  console.log('   DateString:', date1.toDateString());
  console.log('   Month (0-indexed):', date1.getMonth());
  console.log('   Date:', date1.getDate());
  console.log('   Year:', date1.getFullYear());
  console.log('   Is Dec 10?', date1.getMonth() === 11 && date1.getDate() === 10 && date1.getFullYear() === 2025);
  
  // Test 2: Parse with UTC
  const date2 = new Date(data.scheduled_date + 'Z');
  console.log('\n2. new Date(scheduled_date + "Z"):');
  console.log('   Result:', date2);
  console.log('   ISO:', date2.toISOString());
  console.log('   DateString:', date2.toDateString());
  console.log('   Month (0-indexed):', date2.getMonth());
  console.log('   Date:', date2.getDate());
  console.log('   Year:', date2.getFullYear());
  console.log('   Is Dec 10?', date2.getMonth() === 11 && date2.getDate() === 10 && date2.getFullYear() === 2025);
  
  // Test 3: Manual parsing
  const dateStr = data.scheduled_date.split('T')[0]; // Get just the date part
  const [year, month, day] = dateStr.split('-').map(Number);
  const date3 = new Date(year, month - 1, day); // month is 0-indexed
  console.log('\n3. Manual parse new Date(year, month-1, day):');
  console.log('   Result:', date3);
  console.log('   ISO:', date3.toISOString());
  console.log('   DateString:', date3.toDateString());
  console.log('   Month (0-indexed):', date3.getMonth());
  console.log('   Date:', date3.getDate());
  console.log('   Year:', date3.getFullYear());
  console.log('   Is Dec 10?', date3.getMonth() === 11 && date3.getDate() === 10 && date3.getFullYear() === 2025);
}
