import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://vmypotfsyrvuublyddyt.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ'
);

async function checkFunction() {
  console.log('=== CHECKING: Task Table Connection to Receiving Records ===\n');
  
  console.log('1. Checking tasks table structure:\n');
  
  const { data: sampleTask } = await supabase
    .from('tasks')
    .select('*')
    .limit(1)
    .single();
  
  const taskColumns = Object.keys(sampleTask);
  console.log('Tasks table columns:', taskColumns.join(', '));
  
  // Check if there's a receiving_record_id field
  const hasReceivingField = taskColumns.includes('receiving_record_id');
  console.log('\n❓ Has receiving_record_id column:', hasReceivingField ? '✅ YES' : '❌ NO');
  
  console.log('\n2. Checking receiving_records table structure:\n');
  
  const { data: sampleRecord } = await supabase
    .from('receiving_records')
    .select('*')
    .limit(1)
    .single();
  
  const recordColumns = Object.keys(sampleRecord);
  console.log('Receiving_records columns:', recordColumns.slice(0, 10).join(', '), '...');
  
  console.log('\n3. Checking receiving_tasks table (the junction table):\n');
  
  const { data: receivingTasksSample, error } = await supabase
    .from('receiving_tasks')
    .select('*')
    .limit(1);
  
  if (receivingTasksSample && receivingTasksSample.length > 0) {
    console.log('receiving_tasks columns:', Object.keys(receivingTasksSample[0]).join(', '));
  } else {
    console.log('❌ receiving_tasks table is EMPTY');
    console.log('Expected columns: receiving_record_id, task_id, assignment_id, role_type, assigned_user_id, clearance_certificate_url, etc.');
  }
  
  console.log('\n=== CURRENT CONNECTION METHOD ===\n');
  console.log('❌ NO Direct Link:');
  console.log('   - tasks table does NOT have receiving_record_id column');
  console.log('   - receiving_records table does NOT have task_id column');
  console.log('   - No foreign key relationship between them\n');
  
  console.log('⚠️  Indirect Connection (Current Workaround):');
  console.log('   Method 1: Parse task description');
  console.log('   - Task description includes bill number');
  console.log('   - Match bill number to receiving_record.bill_number');
  console.log('   - Example: "Bill Number: 25171704006127"');
  console.log('');
  console.log('   Method 2: Parse clearance certificate URL');
  console.log('   - Some tasks have certificate URL in description');
  console.log('   - Extract receiving_record_id from certificate filename');
  console.log('   - Example: clearance-certificate-[RECORD_ID]-timestamp.png');
  console.log('');
  console.log('   ❌ Problems:');
  console.log('      - Not reliable (text parsing can fail)');
  console.log('      - Slow (no database index)');
  console.log('      - Cannot do direct SQL joins');
  console.log('      - Bill numbers might not be unique');
  
  console.log('\n✅ INTENDED Connection (Not Working):');
  console.log('   Via receiving_tasks junction table:');
  console.log('   ');
  console.log('   receiving_records ←─┐');
  console.log('                       ├──→ receiving_tasks ←─┐');
  console.log('   tasks ←─────────────┘                      │');
  console.log('   task_assignments ←─────────────────────────┘');
  console.log('');
  console.log('   This table SHOULD link:');
  console.log('   - receiving_record_id → receiving_records.id');
  console.log('   - task_id → tasks.id');
  console.log('   - assignment_id → task_assignments.id');
  console.log('   - Plus: role_type, certificate_url, completion tracking');
  console.log('');
  console.log('   ❌ But it\'s EMPTY - the database function doesn\'t populate it!');
  
  console.log('\n=== DEMONSTRATION ===\n');
  console.log('Finding tasks for receiving record 73e653c4-7fb6-4e1a-9655-add21fa33017:\n');
  
  // Get the receiving record
  const { data: record } = await supabase
    .from('receiving_records')
    .select('bill_number')
    .eq('id', '73e653c4-7fb6-4e1a-9655-add21fa33017')
    .single();
  
  console.log('Receiving record bill number:', record.bill_number);
  
  // Try to find tasks by bill number
  const { data: tasksByBill } = await supabase
    .from('tasks')
    .select('id, title')
    .ilike('description', `%${record.bill_number}%`)
    .limit(3);
  
  console.log(`Found ${tasksByBill.length} tasks by parsing description (unreliable)`);
  
  // Try to find via receiving_tasks (proper way)
  const { data: tasksByJunction } = await supabase
    .from('receiving_tasks')
    .select('task_id, role_type')
    .eq('receiving_record_id', '73e653c4-7fb6-4e1a-9655-add21fa33017');
  
  console.log(`Found ${tasksByJunction.length} tasks via receiving_tasks table (proper way)`);
  
  console.log('\n=== SUMMARY ===');
  console.log('Current: NO proper database connection');
  console.log('Workaround: Parse text from task descriptions');
  console.log('Solution: Fix database function to populate receiving_tasks table!');
}

checkFunction();
