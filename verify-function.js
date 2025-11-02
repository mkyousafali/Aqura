import { createClient } from '@supabase/supabase-js';

// Hardcoded credentials for quick check
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function verifyFunction() {
  console.log('🔍 VERIFICATION: process_clearance_certificate_generation\n');
  console.log('='.repeat(80) + '\n');

  try {
    // ========================================
    // 1. CHECK TEMPLATES TABLE
    // ========================================
    console.log('📋 Step 1: Checking receiving_task_templates table...\n');
    const { data: templates, error: templatesError } = await supabase
      .from('receiving_task_templates')
      .select('*')
      .order('priority', { ascending: false });
    
    if (templatesError) {
      console.error('❌ Templates table error:', templatesError.message);
    } else {
      console.log(`✅ Found ${templates.length} templates:`);
      templates.forEach(t => {
        console.log(`   - ${t.role_type}: "${t.title_template}" (Priority: ${t.priority})`);
      });
    }

    // ========================================
    // 2. CHECK RECEIVING_TASKS TABLE STRUCTURE
    // ========================================
    console.log('\n📋 Step 2: Checking receiving_tasks table structure...\n');
    const { data: recTasks, error: recTasksError } = await supabase
      .from('receiving_tasks')
      .select('*')
      .limit(1);
    
    if (!recTasksError) {
      console.log(`✅ receiving_tasks table accessible (${recTasks?.length || 0} records currently)`);
      if (recTasks && recTasks.length > 0) {
        console.log('   Columns:', Object.keys(recTasks[0]).join(', '));
      }
    } else {
      console.error('❌ receiving_tasks error:', recTasksError.message);
    }

    // ========================================
    // 3. GET A RECEIVING RECORD FOR TESTING
    // ========================================
    console.log('\n📋 Step 3: Finding a receiving record to test with...\n');
    const { data: receivingData, error: recError } = await supabase
      .from('receiving_records')
      .select('id, bill_number, clearance_certificate_url, vendor_id, branch_id')
      .not('clearance_certificate_url', 'is', null)
      .limit(1);
    
    if (recError || !receivingData || receivingData.length === 0) {
      console.log('⚠️  No receiving records with certificates found to test');
      return;
    }

    const testRecord = receivingData[0];
    console.log(`✅ Found test record: ${testRecord.bill_number} (ID: ${testRecord.id})`);

    // Check if it already has tasks
    const { data: existingTasks, error: existError } = await supabase
      .from('receiving_tasks')
      .select('id, title, task_status')
      .eq('receiving_record_id', testRecord.id);
    
    if (!existError && existingTasks && existingTasks.length > 0) {
      console.log(`\n⚠️  This record already has ${existingTasks.length} tasks:`);
      existingTasks.forEach(t => {
        console.log(`   - ${t.title} (${t.task_status})`);
      });
      console.log('\n💡 The function will return DUPLICATE_TASKS error (which is correct!)');
    } else {
      console.log('\n✅ This record has no tasks yet - good for testing');
    }

    // ========================================
    // 4. TEST THE FUNCTION
    // ========================================
    console.log('\n📋 Step 4: Testing process_clearance_certificate_generation function...\n');
    
    const { data: result, error: funcError } = await supabase.rpc(
      'process_clearance_certificate_generation',
      {
        receiving_record_id_param: testRecord.id,
        clearance_certificate_url_param: testRecord.clearance_certificate_url || 'test.pdf',
        generated_by_user_id: '00000000-0000-0000-0000-000000000000',
        generated_by_name: 'Test User',
        generated_by_role: 'admin'
      }
    );

    if (funcError) {
      console.error('❌ Function call error:', funcError.message);
      console.log('\nThis might mean:');
      console.log('  1. Function not deployed yet');
      console.log('  2. Parameters mismatch');
      console.log('  3. Missing permissions');
      return;
    }

    console.log('✅ Function executed successfully!\n');
    console.log('Result:', JSON.stringify(result, null, 2));

    // ========================================
    // 5. VERIFY TASKS WERE CREATED
    // ========================================
    if (result && result.success) {
      console.log('\n📋 Step 5: Verifying tasks were created...\n');
      
      const { data: newTasks, error: verifyError } = await supabase
        .from('receiving_tasks')
        .select(`
          id,
          title,
          role_type,
          task_status,
          priority,
          due_date,
          assigned_user_id,
          template_id
        `)
        .eq('receiving_record_id', testRecord.id)
        .order('priority', { ascending: false });
      
      if (!verifyError && newTasks) {
        console.log(`✅ Found ${newTasks.length} tasks in receiving_tasks table:\n`);
        newTasks.forEach((task, idx) => {
          console.log(`${idx + 1}. [${task.role_type}] ${task.title}`);
          console.log(`   Status: ${task.task_status}, Priority: ${task.priority}`);
          console.log(`   Due: ${task.due_date}`);
          console.log(`   Assigned: ${task.assigned_user_id || 'Not assigned'}`);
          console.log(`   Template: ${task.template_id}\n`);
        });
      } else {
        console.error('❌ Could not verify tasks:', verifyError?.message);
      }
    } else if (result && result.error_code === 'DUPLICATE_TASKS') {
      console.log('✅ Function correctly detected duplicate tasks - working as expected!');
    }

    console.log('\n' + '='.repeat(80));
    console.log('✅ VERIFICATION COMPLETE\n');

  } catch (err) {
    console.error('❌ Unexpected error:', err.message);
    console.error(err);
  }
}

// Execute verification
verifyFunction()
  .then(() => {
    console.log('✅ Script complete');
    process.exit(0);
  })
  .catch(err => {
    console.error('❌ Fatal error:', err);
    process.exit(1);
  });
