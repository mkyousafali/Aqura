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

const supabaseUrl = envVars.PUBLIC_SUPABASE_URL || envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.SUPABASE_SERVICE_ROLE_KEY || envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

console.log('Environment check:');
console.log('URL:', supabaseUrl ? '✅ Found' : '❌ Missing');
console.log('Key:', supabaseServiceKey ? '✅ Found' : '❌ Missing');
console.log('');

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing required environment variables!');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

console.log('🔍 Checking Branch Performance Health related tables...\n');

// Check task_assignments table
async function checkTaskAssignments() {
  console.log('📋 TABLE: task_assignments');
  console.log('=' .repeat(60));
  
  const { data, error, count } = await supabase
    .from('task_assignments')
    .select('*', { count: 'exact' })
    .limit(1);

  if (error) {
    console.error('❌ Error:', error.message);
    return;
  }

  console.log(`✅ Total records: ${count}`);
  if (data && data.length > 0) {
    console.log('📊 Columns:', Object.keys(data[0]).join(', '));
    console.log('\n🔍 Sample record:');
    console.log(JSON.stringify(data[0], null, 2));
  }
  console.log('\n');
}

// Check quick_task_assignments table
async function checkQuickTaskAssignments() {
  console.log('📋 TABLE: quick_task_assignments');
  console.log('=' .repeat(60));
  
  const { data, error, count } = await supabase
    .from('quick_task_assignments')
    .select('*', { count: 'exact' })
    .limit(1);

  if (error) {
    console.error('❌ Error:', error.message);
    return;
  }

  console.log(`✅ Total records: ${count}`);
  if (data && data.length > 0) {
    console.log('📊 Columns:', Object.keys(data[0]).join(', '));
    console.log('\n🔍 Sample record:');
    console.log(JSON.stringify(data[0], null, 2));
  }
  console.log('\n');
}

// Check quick_tasks table
async function checkQuickTasks() {
  console.log('📋 TABLE: quick_tasks');
  console.log('=' .repeat(60));
  
  const { data, error, count } = await supabase
    .from('quick_tasks')
    .select('*', { count: 'exact' })
    .limit(1);

  if (error) {
    console.error('❌ Error:', error.message);
    return;
  }

  console.log(`✅ Total records: ${count}`);
  if (data && data.length > 0) {
    console.log('📊 Columns:', Object.keys(data[0]).join(', '));
    console.log('\n🔍 Sample record:');
    console.log(JSON.stringify(data[0], null, 2));
  }
  console.log('\n');
}

// Check receiving_tasks table
async function checkReceivingTasks() {
  console.log('📋 TABLE: receiving_tasks');
  console.log('=' .repeat(60));
  
  const { data, error, count } = await supabase
    .from('receiving_tasks')
    .select('*', { count: 'exact' })
    .limit(1);

  if (error) {
    console.error('❌ Error:', error.message);
    return;
  }

  console.log(`✅ Total records: ${count}`);
  if (data && data.length > 0) {
    console.log('📊 Columns:', Object.keys(data[0]).join(', '));
    console.log('\n🔍 Sample record:');
    console.log(JSON.stringify(data[0], null, 2));
  }
  console.log('\n');
}

// Check users table
async function checkUsers() {
  console.log('📋 TABLE: users');
  console.log('=' .repeat(60));
  
  const { data, error, count } = await supabase
    .from('users')
    .select('*', { count: 'exact' })
    .limit(1);

  if (error) {
    console.error('❌ Error:', error.message);
    return;
  }

  console.log(`✅ Total records: ${count}`);
  if (data && data.length > 0) {
    console.log('📊 Columns:', Object.keys(data[0]).join(', '));
    console.log('\n🔍 Sample record (sensitive data hidden):');
    const sample = { ...data[0] };
    if (sample.password) sample.password = '***';
    if (sample.email) sample.email = sample.email.replace(/(.{2}).*(@.*)/, '$1***$2');
    console.log(JSON.stringify(sample, null, 2));
  }
  console.log('\n');
}

// Test the problematic query
async function testProblematicQuery() {
  console.log('🧪 TESTING PROBLEMATIC QUERY');
  console.log('=' .repeat(60));
  
  const testIds = ['9fe9e217-6953-4d0f-99dd-a8fd8bfded9d', '4ff8b724-ac89-4f55-b453-27145ffa3dd5'];
  
  console.log('Test 1: Using .in() method');
  const { data: data1, error: error1 } = await supabase
    .from('users')
    .select('id, username, full_name')
    .in('id', testIds);
  
  if (error1) {
    console.error('❌ Error with .in():', error1.message);
  } else {
    console.log('✅ Success with .in():', data1?.length, 'records');
  }
  
  console.log('\nTest 2: Using single .eq()');
  const { data: data2, error: error2 } = await supabase
    .from('users')
    .select('id, username, full_name')
    .eq('id', testIds[0]);
  
  if (error2) {
    console.error('❌ Error with .eq():', error2.message);
  } else {
    console.log('✅ Success with .eq():', data2?.length, 'records');
  }
  
  console.log('\n');
}

// Run all checks
async function runChecks() {
  try {
    await checkTaskAssignments();
    await checkQuickTaskAssignments();
    await checkQuickTasks();
    await checkReceivingTasks();
    await checkUsers();
    await testProblematicQuery();
    
    console.log('✅ All checks completed!');
  } catch (err) {
    console.error('❌ Error running checks:', err);
  }
}

runChecks();
