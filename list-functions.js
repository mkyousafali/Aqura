// List all database functions by category
import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

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

console.log('\n🔍 Fetching database functions...\n');

const { data, error } = await supabase.rpc('get_database_functions');

if (error) {
  console.error('Error:', error.message);
  process.exit(1);
}

// Filter only user-defined functions (exclude triggers and system functions)
const functions = data.filter(f => f.routine_type === 'FUNCTION').map(f => f.routine_name);

console.log(`✅ Total: ${functions.length} functions\n`);

// Categorize
const categories = {
  'Task Management': functions.filter(f => f.includes('task') || f.includes('assignment')),
  'Receiving & Vendor': functions.filter(f => f.includes('receiving') || f.includes('vendor') || f.includes('visit')),
  'User Management': functions.filter(f => f.includes('user') || f.includes('password') || f.includes('role')),
  'Employee/HR': functions.filter(f => f.includes('employee') || f.includes('hr')),
  'Financial': functions.filter(f => f.includes('bill') || f.includes('payment') || f.includes('fine') || f.includes('expense')),
  'Notification': functions.filter(f => f.includes('notification') || f.includes('push') || f.includes('reminder')),
  'Customer': functions.filter(f => f.includes('customer')),
  'System/ERP': functions.filter(f => f.includes('http') || f.includes('sync') || f.includes('erp') || f.includes('schema') || f.includes('database'))
};

for (const [category, funcs] of Object.entries(categories)) {
  if (funcs.length > 0) {
    console.log(`\n📂 ${category} (${funcs.length}):`);
    funcs.sort().forEach(f => console.log(`  - ${f}`));
  }
}

console.log('\n✅ Complete!\n');
