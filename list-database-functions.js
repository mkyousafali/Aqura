// Check all database functions in Supabase
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

console.log('\n🔍 Fetching all database functions from Supabase...');
console.log('='.repeat(80));

// Get database functions
const { data, error } = await supabase.rpc('get_database_functions');

if (error) {
  console.error('❌ Error:', error.message);
  process.exit(1);
}

console.log(`\n✅ Found ${data.length} database functions\n`);

// Check structure of first function
if (data.length > 0) {
  console.log('Sample function data structure:');
  console.log(JSON.stringify(data[0], null, 2));
  console.log('\nAll function names:');
  data.forEach((func, idx) => {
    if (idx < 20) { // Show first 20
      console.log(`${idx + 1}. ${JSON.stringify(func)}`);
    }
  });
}

process.exit(0);

// Group functions by category
const categories = {
  'Task Management': [],
  'Receiving & Vendor': [],
  'User Management': [],
  'Employee Management': [],
  'Financial': [],
  'Notification': [],
  'Customer': [],
  'System': [],
  'Miscellaneous': []
};

data.forEach(func => {
  const name = func.function_name || func.name || '';
  
  if (!name) return;
  
  if (name.includes('task') || name.includes('assignment') || name.includes('quick_task')) {
    categories['Task Management'].push(name);
  } else if (name.includes('receiving') || name.includes('vendor') || name.includes('visit')) {
    categories['Receiving & Vendor'].push(name);
  } else if (name.includes('user') || name.includes('password') || name.includes('auth') || name.includes('role')) {
    categories['User Management'].push(name);
  } else if (name.includes('employee') || name.includes('hr')) {
    categories['Employee Management'].push(name);
  } else if (name.includes('bill') || name.includes('payment') || name.includes('fine') || name.includes('expense')) {
    categories['Financial'].push(name);
  } else if (name.includes('notification') || name.includes('push') || name.includes('reminder')) {
    categories['Notification'].push(name);
  } else if (name.includes('customer')) {
    categories['Customer'].push(name);
  } else if (name.includes('http') || name.includes('system') || name.includes('database') || name.includes('sync') || name.includes('schema') || name.includes('erp')) {
    categories['System'].push(name);
  } else {
    categories['Miscellaneous'].push(name);
  }
});

// Display by category
for (const [category, functions] of Object.entries(categories)) {
  if (functions.length > 0) {
    console.log(`\n📂 ${category} (${functions.length} functions):`);
    console.log('-'.repeat(80));
    functions.sort().forEach(func => {
      console.log(`  - ${func}`);
    });
  }
}

console.log('\n' + '='.repeat(80));
console.log(`📈 Total Functions: ${data.length}`);
console.log('\n✅ Check complete!\n');
