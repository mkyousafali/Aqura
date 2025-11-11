import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

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

const receivingRecordId = '79913f8f-ca82-4482-8c22-5a84ac06f0a0'; // The new one failing
const taskId = '9871acc0-9bac-4dc4-993e-7a1117522599';

console.log('🔍 Checking receiving record:', receivingRecordId);
console.log('='.repeat(60));

// Get receiving record
const { data: record, error: recordError } = await supabase
  .from('receiving_records')
  .select('*')
  .eq('id', receivingRecordId)
  .single();

if (recordError) {
  console.error('❌ Error fetching record:', recordError);
  process.exit(1);
}

console.log('\n📦 Receiving Record Details:');
console.log('   - ERP Reference:', record.erp_purchase_invoice_reference);
console.log('   - ERP Uploaded:', record.erp_purchase_invoice_uploaded ? '✅' : '❌');
console.log('   - PR Excel URL:', record.pr_excel_file_url ? '✅' : '❌');
console.log('   - PR Excel Uploaded:', record.pr_excel_file_uploaded ? '✅' : '❌');
console.log('   - Original Bill URL:', record.original_bill_url ? '✅' : '❌');
console.log('   - Original Bill Uploaded:', record.original_bill_uploaded ? '✅' : '❌');

// Get all tasks
const { data: tasks, error: tasksError } = await supabase
  .from('receiving_tasks')
  .select('*')
  .eq('receiving_record_id', receivingRecordId)
  .order('created_at');

if (tasksError) {
  console.error('❌ Error fetching tasks:', tasksError);
  process.exit(1);
}

console.log('\n📋 Tasks Status:');
console.log('-'.repeat(60));
tasks.forEach(task => {
  const status = task.task_completed ? '✅' : '❌';
  console.log(`${status} ${task.role_type.padEnd(25)} | Completed: ${task.task_completed.toString().padEnd(5)} | Task ID: ${task.id}`);
});

const inventoryTask = tasks.find(t => t.role_type === 'inventory_manager');
const accountantTask = tasks.find(t => t.role_type === 'accountant');

console.log('\n🎯 Analysis:');
console.log('-'.repeat(60));

if (!inventoryTask) {
  console.log('⚠️  NO INVENTORY MANAGER TASK EXISTS!');
  console.log('✅ Files uploaded: PR Excel ✅ | Original Bill ✅');
  console.log('❌ But database function is checking for inventory_manager task completion');
} else {
  console.log('Inventory Manager Task:');
  console.log('  - Exists:', inventoryTask ? 'YES' : 'NO');
  console.log('  - Completed:', inventoryTask?.task_completed);
}

console.log('\n💡 Issue: Database function needs to be updated!');
console.log('📝 SQL to run in Supabase Dashboard:\n');

console.log(`
-- Fix for complete_receiving_task_simple function
-- Need to replace inventory_manager task check with file upload check

-- For accountant role, change from:
--   IF NOT inventory_task_completed THEN
--     RETURN json_build_object(
--       'success', false,
--       'error', 'The Inventory Manager must complete their task...',
--       'error_code', 'INVENTORY_MANAGER_NOT_COMPLETED'
--     );
--   END IF;

-- To:
--   IF NOT (receiving_record.pr_excel_file_uploaded AND receiving_record.original_bill_uploaded) THEN
--     RETURN json_build_object(
--       'success', false,
--       'error', 'Required files not uploaded. Please ensure PR Excel and Original Bill are uploaded.',
--       'error_code', 'REQUIRED_FILES_NOT_UPLOADED'
--     );
--   END IF;
`);
