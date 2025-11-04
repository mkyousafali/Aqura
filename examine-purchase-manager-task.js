// Script to examine existing purchase manager task details
import { createClient } from '@supabase/supabase-js';

// Configuration
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

// Create Supabase client with service role key
const supabase = createClient(supabaseUrl, serviceRoleKey);

async function examinePurchaseManagerTask() {
  console.log('🔍 EXAMINING PURCHASE MANAGER TASK DETAILS');
  console.log('=========================================\n');

  try {
    // Get the existing purchase manager task
    const { data: tasks, error: taskError } = await supabase
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
        created_at,
        updated_at
      `)
      .eq('role_type', 'purchase_manager')
      .order('created_at', { ascending: false })
      .limit(1);

    if (taskError) {
      console.error('❌ Error fetching task:', taskError);
      return;
    }

    if (!tasks?.length) {
      console.log('❌ No purchase manager tasks found');
      return;
    }

    const task = tasks[0];
    console.log('✅ Purchase Manager Task Found:');
    console.log(`   Task ID: ${task.id}`);
    console.log(`   Receiving Record ID: ${task.receiving_record_id}`);
    console.log(`   Title: ${task.title}`);
    console.log(`   Assigned User ID: ${task.assigned_user_id}`);
    console.log(`   Priority: ${task.priority}`);
    console.log(`   Status: ${task.task_status}`);
    console.log(`   Completed: ${task.task_completed}`);
    console.log(`   Due Date: ${task.due_date}`);
    console.log(`   Created: ${task.created_at}`);
    console.log(`   Certificate URL: ${task.clearance_certificate_url}`);
    console.log('');

    // Get user details for the assigned purchase manager
    console.log('👤 Getting Purchase Manager Details...\n');
    
    const { data: userDetails, error: userError } = await supabase
      .from('users')
      .select(`
        id,
        username,
        email,
        display_name,
        employee_id,
        role_type
      `)
      .eq('id', task.assigned_user_id)
      .single();

    if (userError) {
      console.error('❌ Error fetching user details:', userError);
    } else {
      console.log('✅ Assigned Purchase Manager:');
      console.log(`   User ID: ${userDetails.id}`);
      console.log(`   Username: ${userDetails.username}`);
      console.log(`   Email: ${userDetails.email}`);
      console.log(`   Display Name: ${userDetails.display_name}`);
      console.log(`   Role Type: ${userDetails.role_type}`);
      console.log(`   Employee ID: ${userDetails.employee_id}`);
      console.log('');
    }

    // Get receiving record details
    console.log('📦 Getting Receiving Record Details...\n');
    
    const { data: recordDetails, error: recordError } = await supabase
      .from('receiving_records')
      .select(`
        id,
        bill_number,
        vendor_id,
        branch_id,
        bill_amount,
        bill_date,
        user_id,
        created_at
      `)
      .eq('id', task.receiving_record_id)
      .single();

    if (recordError) {
      console.error('❌ Error fetching receiving record:', recordError);
    } else {
      console.log('✅ Receiving Record Details:');
      console.log(`   Record ID: ${recordDetails.id}`);
      console.log(`   Bill Number: ${recordDetails.bill_number}`);
      console.log(`   Vendor ID: ${recordDetails.vendor_id}`);
      console.log(`   Branch ID: ${recordDetails.branch_id}`);
      console.log(`   Bill Amount: $${recordDetails.bill_amount}`);
      console.log(`   Bill Date: ${recordDetails.bill_date}`);
      console.log(`   Received By User ID: ${recordDetails.user_id}`);
      console.log(`   Created: ${recordDetails.created_at}`);
      console.log('');
    }

    // Check for notifications sent to this purchase manager
    console.log('📧 Checking Notifications...\n');
    
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
        sent_at,
        metadata
      `)
      .contains('target_users', [task.assigned_user_id])
      .eq('type', 'task')
      .order('created_at', { ascending: false })
      .limit(3);

    if (notifError) {
      console.error('❌ Error checking notifications:', notifError);
    } else if (notifications?.length > 0) {
      console.log(`✅ Found ${notifications.length} related notification(s):`);
      notifications.forEach((notif, index) => {
        console.log(`   ${index + 1}. ${notif.title}`);
        console.log(`      Status: ${notif.status}`);
        console.log(`      Priority: ${notif.priority}`);
        console.log(`      Created: ${notif.created_at}`);
        console.log(`      Sent: ${notif.sent_at}`);
        if (notif.metadata?.task_id === task.id) {
          console.log('      ✅ This notification is for our task!');
        }
        console.log('');
      });
    } else {
      console.log('⚠️ No notifications found for this purchase manager');
    }

    // Show the full task description
    console.log('📝 FULL TASK DESCRIPTION:');
    console.log('========================');
    console.log(task.description);
    console.log('========================\n');

    // Show the deadline calculation
    const now = new Date();
    const dueDate = new Date(task.due_date);
    const hoursRemaining = Math.round((dueDate - now) / (1000 * 60 * 60));
    
    console.log('⏰ DEADLINE INFORMATION:');
    console.log(`   Due Date: ${dueDate.toLocaleString()}`);
    console.log(`   Current Time: ${now.toLocaleString()}`);
    console.log(`   Hours Remaining: ${hoursRemaining > 0 ? hoursRemaining : 'OVERDUE'}`);
    console.log(`   Status: ${hoursRemaining > 0 ? '✅ On Time' : '❌ Overdue'}`);
    
    console.log('\n✅ Analysis completed successfully!');
    console.log('=========================================');

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

// Run the analysis
examinePurchaseManagerTask();