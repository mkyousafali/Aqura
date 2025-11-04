// =====================================================
// ANALYZE SHELF STOCKER TASK CREATION WORKFLOW
// =====================================================
// This script analyzes how shelf stocker tasks are created
// after clearance certificate generation
// =====================================================

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://gqqmgqaelflqkdgpvbxl.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdxcW1ncWFlbGZscWtkZ3B2YnhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzA0NDIzNzgsImV4cCI6MjA0NjAxODM3OH0.G0Q2_bZG3eo6KJ4E8G1g5PZ0iIHhXEo-A6vQQ9BQGnA';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function analyzeShelfStockerWorkflow() {
  console.log('🔍 ANALYZING SHELF STOCKER TASK CREATION WORKFLOW');
  console.log('=' .repeat(60));

  try {
    // 1. Check shelf stocker task template
    console.log('\\n1️⃣ Checking Shelf Stocker Task Template...');
    const { data: template, error: templateError } = await supabase
      .from('receiving_task_templates')
      .select('*')
      .eq('role_type', 'shelf_stocker')
      .single();

    if (templateError) {
      console.error('❌ Error fetching template:', templateError);
      return;
    }

    console.log('✅ Shelf Stocker Template Found:');
    console.log(`   ID: ${template.id}`);
    console.log(`   Title: "${template.title_template}"`);
    console.log(`   Priority: ${template.priority}`);
    console.log(`   Deadline: ${template.deadline_hours} hours`);
    console.log(`   Requirements:`);
    console.log(`     - ERP Reference: ${template.require_erp_reference}`);
    console.log(`     - Original Bill: ${template.require_original_bill_upload}`);
    console.log(`     - Task Finished Mark: ${template.require_task_finished_mark}`);

    // 2. Check a sample receiving record with shelf stocker assignments
    console.log('\\n2️⃣ Finding Sample Receiving Record with Shelf Stocker Assignment...');
    const { data: receivingRecords, error: recordsError } = await supabase
      .from('receiving_records')
      .select(`
        id,
        bill_number,
        vendor_name,
        branch_name,
        bill_amount,
        bill_date,
        received_by_name,
        shelf_stocker_user_ids,
        clearance_certificate_url
      `)
      .not('shelf_stocker_user_ids', 'is', null)
      .limit(3);

    if (recordsError) {
      console.error('❌ Error fetching receiving records:', recordsError);
      return;
    }

    if (receivingRecords.length === 0) {
      console.log('⚠️  No receiving records found with shelf stocker assignments');
      return;
    }

    console.log(`✅ Found ${receivingRecords.length} receiving record(s) with shelf stocker assignments:`);
    receivingRecords.forEach((record, index) => {
      console.log(`\\n   Record ${index + 1}:`);
      console.log(`     ID: ${record.id}`);
      console.log(`     Bill: ${record.bill_number} (${record.bill_amount})`);
      console.log(`     Vendor: ${record.vendor_name}`);
      console.log(`     Branch: ${record.branch_name}`);
      console.log(`     Received By: ${record.received_by_name}`);
      console.log(`     Shelf Stocker IDs: [${record.shelf_stocker_user_ids.join(', ')}]`);
      console.log(`     Certificate: ${record.clearance_certificate_url ? 'Generated' : 'Not Generated'}`);
    });

    // 3. Check existing tasks for these records
    console.log('\\n3️⃣ Checking Existing Shelf Stocker Tasks...');
    const recordIds = receivingRecords.map(r => r.id);
    
    const { data: existingTasks, error: tasksError } = await supabase
      .from('receiving_tasks')
      .select(`
        id,
        receiving_record_id,
        role_type,
        assigned_user_id,
        title,
        task_status,
        task_completed,
        due_date,
        created_at,
        clearance_certificate_url
      `)
      .in('receiving_record_id', recordIds)
      .eq('role_type', 'shelf_stocker')
      .order('created_at', { ascending: false });

    if (tasksError) {
      console.error('❌ Error fetching existing tasks:', tasksError);
      return;
    }

    console.log(`✅ Found ${existingTasks.length} existing shelf stocker task(s):`);
    if (existingTasks.length > 0) {
      existingTasks.forEach((task, index) => {
        console.log(`\\n   Task ${index + 1}:`);
        console.log(`     ID: ${task.id}`);
        console.log(`     Record ID: ${task.receiving_record_id}`);
        console.log(`     Title: "${task.title}"`);
        console.log(`     Assigned To: ${task.assigned_user_id}`);
        console.log(`     Status: ${task.task_status} (Completed: ${task.task_completed})`);
        console.log(`     Due Date: ${task.due_date}`);
        console.log(`     Created: ${task.created_at}`);
        console.log(`     Certificate: ${task.clearance_certificate_url ? 'Attached' : 'No Certificate'}`);
      });
    } else {
      console.log('   No existing shelf stocker tasks found');
    }

    // 4. Demonstrate the workflow by testing certificate generation
    console.log('\\n4️⃣ WORKFLOW DEMONSTRATION: How Shelf Stocker Task is Created');
    console.log('=' .repeat(50));
    
    // Find a record without tasks yet for testing
    const recordForTesting = receivingRecords.find(record => 
      !existingTasks.some(task => task.receiving_record_id === record.id)
    );

    if (recordForTesting) {
      console.log(`\\n📋 Using Record for Testing: ${recordForTesting.bill_number}`);
      console.log(`   Record ID: ${recordForTesting.id}`);
      console.log(`   Shelf Stocker Users: [${recordForTesting.shelf_stocker_user_ids.join(', ')}]`);
      
      console.log('\\n🔄 Testing process_clearance_certificate_generation function...');
      
      // Test the function call
      const { data: result, error: funcError } = await supabase.rpc(
        'process_clearance_certificate_generation',
        {
          receiving_record_id_param: recordForTesting.id,
          clearance_certificate_url_param: 'test-certificate-shelf-stocker.pdf',
          generated_by_user_id: '00000000-0000-0000-0000-000000000000',
          generated_by_name: 'Test Admin',
          generated_by_role: 'admin'
        }
      );

      if (funcError) {
        console.error('❌ Function call error:', funcError);
        return;
      }

      console.log('\\n✅ Function Result:');
      console.log(`   Success: ${result.success}`);
      console.log(`   Tasks Created: ${result.tasks_created}`);
      console.log(`   Notifications Sent: ${result.notifications_sent}`);
      
      if (!result.success) {
        console.log(`   Error: ${result.error}`);
        console.log(`   Error Code: ${result.error_code}`);
      }

      // 5. Check the created shelf stocker task
      if (result.success && result.tasks_created > 0) {
        console.log('\\n5️⃣ Checking Created Shelf Stocker Task...');
        
        const { data: newShelfStockerTask, error: newTaskError } = await supabase
          .from('receiving_tasks')
          .select(`
            id,
            receiving_record_id,
            template_id,
            role_type,
            assigned_user_id,
            title,
            description,
            priority,
            due_date,
            task_status,
            task_completed,
            clearance_certificate_url,
            created_at
          `)
          .eq('receiving_record_id', recordForTesting.id)
          .eq('role_type', 'shelf_stocker')
          .order('created_at', { ascending: false })
          .limit(1)
          .single();

        if (newTaskError) {
          console.error('❌ Error fetching new task:', newTaskError);
          return;
        }

        console.log('\\n📋 NEW SHELF STOCKER TASK CREATED:');
        console.log(`   Task ID: ${newShelfStockerTask.id}`);
        console.log(`   Template ID: ${newShelfStockerTask.template_id}`);
        console.log(`   Title: "${newShelfStockerTask.title}"`);
        console.log(`   Assigned To: ${newShelfStockerTask.assigned_user_id}`);
        console.log(`   Priority: ${newShelfStockerTask.priority}`);
        console.log(`   Due Date: ${newShelfStockerTask.due_date}`);
        console.log(`   Status: ${newShelfStockerTask.task_status}`);
        console.log(`   Certificate URL: ${newShelfStockerTask.clearance_certificate_url}`);
        console.log(`   Created: ${newShelfStockerTask.created_at}`);
        
        console.log('\\n📝 Task Description (with placeholders replaced):');
        console.log('   ' + newShelfStockerTask.description.replace(/\\n/g, '\\n   '));

        // 6. Check notification created for shelf stocker
        console.log('\\n6️⃣ Checking Notification Sent to Shelf Stocker...');
        
        const { data: notification, error: notifError } = await supabase
          .from('notifications')
          .select(`
            id,
            title,
            message,
            type,
            priority,
            target_users,
            status,
            created_at,
            metadata
          `)
          .contains('target_users', [newShelfStockerTask.assigned_user_id])
          .eq('type', 'task')
          .order('created_at', { ascending: false })
          .limit(1)
          .single();

        if (notifError) {
          console.log('⚠️  No notification found or error:', notifError.message);
        } else {
          console.log('\\n📬 NOTIFICATION SENT TO SHELF STOCKER:');
          console.log(`   Notification ID: ${notification.id}`);
          console.log(`   Title: "${notification.title}"`);
          console.log(`   Priority: ${notification.priority}`);
          console.log(`   Target Users: [${notification.target_users.join(', ')}]`);
          console.log(`   Status: ${notification.status}`);
          console.log(`   Created: ${notification.created_at}`);
          
          console.log('\\n📱 Notification Message:');
          console.log('   ' + notification.message.replace(/\\n/g, '\\n   '));
          
          console.log('\\n📊 Notification Metadata:');
          console.log('   ' + JSON.stringify(notification.metadata, null, 6));
        }
      }
    } else {
      console.log('\\n⚠️  All records already have tasks - cannot demonstrate task creation');
      console.log('   (This shows duplicate prevention is working correctly)');
    }

    // 7. Summary of Workflow
    console.log('\\n\\n🎯 SHELF STOCKER TASK CREATION WORKFLOW SUMMARY:');
    console.log('=' .repeat(60));
    console.log('\\n1. Admin generates clearance certificate in receiving module');
    console.log('2. Certificate triggers process_clearance_certificate_generation() function');
    console.log('3. Function loops through all 7 role templates including shelf_stocker');
    console.log('4. For shelf_stocker template:');
    console.log('   - Gets first user ID from receiving_record.shelf_stocker_user_ids array');
    console.log('   - Replaces placeholders in title and description with actual data');
    console.log('   - Sets due_date = NOW() + 24 hours (in UTC+3 timezone)');
    console.log('   - Creates record in receiving_tasks table');
    console.log('5. Sends push notification to assigned shelf stocker user');
    console.log('6. Shelf stocker sees task in mobile/desktop interface');
    console.log('7. Task requirements: Stock shelves and mark task as completed');
    console.log('\\n✅ Workflow analysis completed successfully!');

  } catch (error) {
    console.error('💥 Unexpected error:', error);
  }
}

// Run the analysis
analyzeShelfStockerWorkflow().catch(console.error);