// Test script to examine purchase manager task creation using server role key
import { createClient } from '@supabase/supabase-js';

// Configuration
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

// Create Supabase client with service role key (bypasses RLS)
const supabase = createClient(supabaseUrl, serviceRoleKey);

async function testPurchaseManagerTaskCreation() {
  console.log('🔍 TESTING PURCHASE MANAGER TASK CREATION PROCESS');
  console.log('===============================================\n');

  try {
    // 1. Check receiving task templates for purchase_manager
    console.log('1️⃣ Checking purchase_manager template...\n');
    
    const { data: templates, error: templateError } = await supabase
      .from('receiving_task_templates')
      .select('*')
      .eq('role_type', 'purchase_manager')
      .single();

    if (templateError) {
      console.error('❌ Error fetching purchase_manager template:', templateError);
      return;
    }

    console.log('✅ Purchase Manager Template Found:');
    console.log(`   Title: ${templates.title_template}`);
    console.log(`   Deadline: ${templates.deadline_hours} hours`);
    console.log(`   Priority: ${templates.priority}`);
    console.log(`   Description Preview: ${templates.description_template.substring(0, 100)}...`);
    console.log('');

    // 2. Get a sample receiving record to test with
    console.log('2️⃣ Finding a test receiving record...\n');
    
    const { data: receivingRecords, error: recordError } = await supabase
      .from('receiving_records')
      .select(`
        id,
        bill_number,
        vendor_id,
        branch_id,
        bill_amount,
        bill_date,
        purchasing_manager_user_id
      `)
      .limit(1)
      .order('created_at', { ascending: false });

    if (recordError || !receivingRecords?.length) {
      console.error('❌ No receiving records found:', recordError);
      return;
    }

    const testRecord = receivingRecords[0];
    console.log('✅ Test Receiving Record Found:');
    console.log(`   ID: ${testRecord.id}`);
    console.log(`   Bill Number: ${testRecord.bill_number}`);
    console.log(`   Vendor ID: ${testRecord.vendor_id}`);
    console.log(`   Bill Amount: ${testRecord.bill_amount}`);
    console.log(`   Purchase Manager ID: ${testRecord.purchasing_manager_user_id}`);
    console.log('');

    // 3. Check if tasks already exist for this record
    console.log('3️⃣ Checking existing tasks...\n');
    
    const { data: existingTasks, error: taskError } = await supabase
      .from('receiving_tasks')
      .select('*')
      .eq('receiving_record_id', testRecord.id)
      .eq('role_type', 'purchase_manager');

    if (taskError) {
      console.error('❌ Error checking existing tasks:', taskError);
      return;
    }

    if (existingTasks?.length > 0) {
      console.log('⚠️ Tasks already exist for this record:');
      existingTasks.forEach(task => {
        console.log(`   - ${task.title} (Status: ${task.task_status})`);
        console.log(`     Assigned to: ${task.assigned_user_id}`);
        console.log(`     Due: ${task.due_date}`);
        console.log(`     Created: ${task.created_at}`);
      });
      console.log('\n🔄 Testing with existing tasks (should return DUPLICATE_TASKS error)...\n');
    } else {
      console.log('✅ No existing tasks found - ready for testing\n');
    }

    // 4. Test the clearance certificate generation function
    console.log('4️⃣ Testing process_clearance_certificate_generation function...\n');
    
    const { data: result, error: funcError } = await supabase.rpc(
      'process_clearance_certificate_generation',
      {
        receiving_record_id_param: testRecord.id,
        clearance_certificate_url_param: 'test-certificate.pdf',
        generated_by_user_id: '00000000-0000-0000-0000-000000000000', // Test user ID
        generated_by_name: 'Test Admin',
        generated_by_role: 'admin'
      }
    );

    if (funcError) {
      console.error('❌ Function execution error:', funcError);
      return;
    }

    console.log('📋 Function Result:');
    console.log(`   Success: ${result.success}`);
    console.log(`   Tasks Created: ${result.tasks_created}`);
    console.log(`   Notifications Sent: ${result.notifications_sent}`);
    
    if (!result.success) {
      console.log(`   Error: ${result.error}`);
      console.log(`   Error Code: ${result.error_code}`);
    }
    console.log('');

    // 5. Verify purchase manager task was created (if function succeeded)
    if (result.success && result.tasks_created > 0) {
      console.log('5️⃣ Verifying purchase manager task creation...\n');
      
      const { data: newTasks, error: verifyError } = await supabase
        .from('receiving_tasks')
        .select(`
          id,
          title,
          description,
          role_type,
          assigned_user_id,
          priority,
          due_date,
          task_status,
          clearance_certificate_url,
          created_at
        `)
        .eq('receiving_record_id', testRecord.id)
        .eq('role_type', 'purchase_manager')
        .order('created_at', { ascending: false })
        .limit(1);

      if (verifyError) {
        console.error('❌ Error verifying task creation:', verifyError);
        return;
      }

      if (newTasks?.length > 0) {
        const purchaseTask = newTasks[0];
        console.log('✅ Purchase Manager Task Created Successfully:');
        console.log(`   Task ID: ${purchaseTask.id}`);
        console.log(`   Title: ${purchaseTask.title}`);
        console.log(`   Assigned User: ${purchaseTask.assigned_user_id}`);
        console.log(`   Priority: ${purchaseTask.priority}`);
        console.log(`   Status: ${purchaseTask.task_status}`);
        console.log(`   Due Date: ${purchaseTask.due_date}`);
        console.log(`   Certificate URL: ${purchaseTask.clearance_certificate_url}`);
        console.log('');
        console.log('📝 Task Description:');
        console.log(purchaseTask.description);
        console.log('');

        // 6. Check if notification was sent
        console.log('6️⃣ Checking notifications...\n');
        
        const { data: notifications, error: notifError } = await supabase
          .from('notifications')
          .select(`
            id,
            title,
            message,
            type,
            priority,
            status,
            target_users,
            created_at,
            metadata
          `)
          .contains('metadata', { task_id: purchaseTask.id })
          .order('created_at', { ascending: false })
          .limit(1);

        if (notifError) {
          console.error('❌ Error checking notifications:', notifError);
        } else if (notifications?.length > 0) {
          const notification = notifications[0];
          console.log('✅ Notification Created:');
          console.log(`   ID: ${notification.id}`);
          console.log(`   Title: ${notification.title}`);
          console.log(`   Type: ${notification.type}`);
          console.log(`   Priority: ${notification.priority}`);
          console.log(`   Status: ${notification.status}`);
          console.log(`   Target Users: ${JSON.stringify(notification.target_users)}`);
          console.log(`   Created: ${notification.created_at}`);
          console.log('');
          console.log('📧 Notification Message:');
          console.log(notification.message);
        } else {
          console.log('⚠️ No notification found for this task');
        }
        
      } else {
        console.log('❌ Purchase manager task not found after creation');
      }
    }

    console.log('\n✅ Test completed successfully!');
    console.log('===============================================');

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

// Run the test
testPurchaseManagerTaskCreation();