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

const supabaseUrl = envVars.VITE_SUPABASE_URL || envVars.PUBLIC_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY || envVars.SUPABASE_SERVICE_ROLE_KEY;
const supabase = createClient(supabaseUrl, supabaseServiceKey);

console.log('🔍 Checking Employee ID Sync Status\n');

try {
  // Get all unique employee IDs from fingerprint transactions
  const { data: transactions, error: transError } = await supabase
    .from('hr_fingerprint_transactions')
    .select('employee_id')
    .eq('branch_id', 3);

  if (transError) throw transError;

  const uniqueEmpIds = [...new Set(transactions.map(t => t.employee_id))].sort();
  console.log(`📊 Found ${uniqueEmpIds.length} unique employee IDs in fingerprint transactions`);
  console.log(`   Sample IDs: ${uniqueEmpIds.slice(0, 10).join(', ')}\n`);

  // Get all employee IDs from hr_employees
  const { data: employees, error: empError } = await supabase
    .from('hr_employees')
    .select('id, employee_id, name, branch_id')
    .eq('branch_id', 3);

  if (empError) throw empError;

  console.log(`👥 Found ${employees.length} employees in hr_employees (Branch 3)`);
  console.log(`   Sample employees:${employees.slice(0, 5).map(e => 
    `\n      - ID: ${e.employee_id}, Name: ${e.name || 'N/A'}`
  ).join('')}\n`);

  // Check for mismatches
  const hrEmployeeIds = employees.map(e => e.employee_id);
  const missingInHR = uniqueEmpIds.filter(id => !hrEmployeeIds.includes(id));
  const matchingIds = uniqueEmpIds.filter(id => hrEmployeeIds.includes(id));

  console.log('🔍 Matching Analysis:');
  console.log(`   ✅ Matching IDs: ${matchingIds.length} (${((matchingIds.length / uniqueEmpIds.length) * 100).toFixed(1)}%)`);
  console.log(`   ❌ Missing in HR: ${missingInHR.length}`);

  if (missingInHR.length > 0) {
    console.log('\n⚠️  Employee IDs in biometric data but NOT in hr_employees:');
    missingInHR.forEach(id => {
      const count = transactions.filter(t => t.employee_id === id).length;
      console.log(`   - ${id} (${count} punch records)`);
    });
    
    console.log('\n💡 Recommendation:');
    console.log('   These employees should be synced from ZKBioTime to hr_employees.');
    console.log('   Run the employee sync function to import them.');
  } else {
    console.log('\n✅ All employee IDs match! No sync needed.');
  }

  // Check if there are employees in HR without any punch records
  const employeesWithoutPunches = hrEmployeeIds.filter(id => !uniqueEmpIds.includes(id));
  if (employeesWithoutPunches.length > 0) {
    console.log(`\n📋 Employees in HR but no punch records: ${employeesWithoutPunches.length}`);
    console.log(`   (This is normal for new employees or those who haven't punched yet)`);
  }

} catch (error) {
  console.error('❌ Error:', error.message);
  process.exit(1);
}
