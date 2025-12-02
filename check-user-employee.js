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
      const value = match[2].trim().replace(/^["']|["']$/g, ''); // Remove quotes
      envVars[key] = value;
    }
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

console.log('Supabase URL:', supabaseUrl);
console.log('Service Key:', supabaseServiceKey ? '***' + supabaseServiceKey.slice(-10) : 'missing');

const supabase = createClient(supabaseUrl, supabaseServiceKey);

const userId = 'b658eca1-3cc1-48b2-bd3c-33b81fab5a0f';

console.log('🔍 Checking user employee data...\n');

// Check user
const { data: user, error: userError } = await supabase
  .from('users')
  .select('id, username, employee_id')
  .eq('id', userId)
  .single();

if (userError) {
  console.error('❌ User error:', userError);
  process.exit(1);
}

console.log('👤 User:', user);

if (!user.employee_id) {
  console.log('\n⚠️  User has no employee_id linked!');
  process.exit(0);
}

// Check employee
const { data: employee, error: empError } = await supabase
  .from('hr_employees')
  .select('id, employee_id, branch_id, name_en, name_ar')
  .eq('id', user.employee_id)
  .single();

if (empError) {
  console.error('❌ Employee error:', empError);
  process.exit(1);
}

console.log('\n👷 Employee:', employee);

// Check punch records
if (employee.employee_id && employee.branch_id) {
  const twoDaysAgo = new Date();
  twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);
  const cutoffDate = twoDaysAgo.toISOString().split('T')[0];
  
  const { data: punches, error: punchError, count } = await supabase
    .from('hr_fingerprint_transactions')
    .select('date, time, status', { count: 'exact' })
    .eq('employee_id', employee.employee_id)
    .eq('branch_id', employee.branch_id)
    .gte('date', cutoffDate)
    .order('date', { ascending: false })
    .order('time', { ascending: false })
    .limit(10);
  
  console.log(`\n⏱️  Punch records (last 48h): ${count} total`);
  
  if (punchError) {
    console.error('❌ Punch error:', punchError);
  } else if (punches && punches.length > 0) {
    console.log('\nLast 10 punches:');
    punches.forEach((p, i) => {
      console.log(`  ${i + 1}. ${p.date} ${p.time} - ${p.status}`);
    });
  } else {
    console.log('❌ No punch records found!');
  }
}
