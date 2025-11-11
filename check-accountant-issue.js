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

const receivingRecordId = '7cfa516e-4974-40b0-91db-a2c74783e532';

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
console.log('   - Inventory Manager ID:', record.inventory_manager_user_id);

// Get all tasks for this record
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
  console.log(`${status} ${task.role_type.padEnd(25)} | Completed: ${task.task_completed.toString().padEnd(5)} | Status: ${task.task_status || 'N/A'}`);
  if (task.role_type === 'inventory_manager') {
    console.log(`   - requires_original_bill_upload: ${task.requires_original_bill_upload}`);
    console.log(`   - original_bill_uploaded: ${task.original_bill_uploaded}`);
    console.log(`   - completed_at: ${task.completed_at || 'Not completed'}`);
  }
});

console.log('\n🎯 Analysis:');
console.log('-'.repeat(60));

const inventoryTask = tasks.find(t => t.role_type === 'inventory_manager');
const accountantTask = tasks.find(t => t.role_type === 'accountant');

if (inventoryTask) {
  console.log('Inventory Manager Task:');
  console.log('  - Task Completed:', inventoryTask.task_completed);
  console.log('  - Task Status:', inventoryTask.task_status);
  console.log('  - Original Bill Uploaded (task):', inventoryTask.original_bill_uploaded);
  console.log('  - Requires Original Bill Upload:', inventoryTask.requires_original_bill_upload);
}

if (accountantTask) {
  console.log('\nAccountant Task:');
  console.log('  - Task ID:', accountantTask.id);
  console.log('  - Task Completed:', accountantTask.task_completed);
  console.log('  - Task Status:', accountantTask.task_status);
}

console.log('\nReceiving Record Upload Flags:');
console.log('  - pr_excel_file_uploaded:', record.pr_excel_file_uploaded);
console.log('  - original_bill_uploaded:', record.original_bill_uploaded);
console.log('  - erp_purchase_invoice_uploaded:', record.erp_purchase_invoice_uploaded);

console.log('\n💡 Issue:');
if (!inventoryTask) {
  console.log('⚠️  NO INVENTORY MANAGER TASK EXISTS for this receiving record!');
  console.log('⚠️  But the system checks for inventory_manager task completion before allowing Accountant.');
  console.log('⚠️  Files are uploaded (PR Excel & Original Bill), so Accountant should be able to complete.');
  console.log('\n🔧 Solution: Update logic to check file uploads instead of inventory_manager task.');
} else if (!inventoryTask.task_completed && record.original_bill_uploaded && record.pr_excel_file_uploaded) {
  console.log('⚠️  Inventory Manager task is NOT completed, but both files are uploaded!');
  console.log('⚠️  The system is blocking Accountant from completing because it checks task_completed flag.');
  console.log('⚠️  Need to fix logic: If files are uploaded, Accountant should be able to proceed.');
}
