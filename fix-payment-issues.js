import { createClient } from '@supabase/supabase-js';

// Supabase configuration
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function fixPaymentIssues() {
  console.log('🔧 Fixing payment automation issues...');
  
  try {
    // 1. Find payment transactions without tasks
    console.log('\n📋 Step 1: Finding payment transactions without tasks...');
    const { data: transactionsWithoutTasks, error: transactionError } = await supabase
      .from('payment_transactions')
      .select('id, payment_schedule_id, vendor_name, bill_number, amount, task_id')
      .is('task_id', null);
    
    if (transactionError) {
      console.log('❌ Error fetching transactions:', transactionError);
      return;
    }
    
    console.log(`Found ${transactionsWithoutTasks.length} transactions without tasks`);
    
    // 2. Create tasks for these transactions
    for (const transaction of transactionsWithoutTasks) {
      console.log(`\n⚡ Creating task for transaction ${transaction.id}...`);
      
      // Create task
      const { data: taskData, error: taskError } = await supabase
        .from('tasks')
        .insert({
          title: `Payment Processing - ${transaction.bill_number}`,
          description: `Process payment transaction for ${transaction.vendor_name} - Amount: ${transaction.amount} SAR\n\nTransaction ID: ${transaction.id}\n\nPlease verify payment details and complete the transaction processing.`,
          status: 'active',
          priority: 'high',
          require_task_finished: true,
          require_photo_upload: false,
          require_erp_reference: true,
          can_escalate: true,
          can_reassign: true,
          created_by: 'system',
          created_by_name: 'Payment Automation Fix',
          created_by_role: 'system',
          due_date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString().split('T')[0] // 3 days from now
        })
        .select()
        .single();
      
      if (taskError) {
        console.log(`❌ Error creating task for transaction ${transaction.id}:`, taskError);
        continue;
      }
      
      console.log(`✅ Created task ${taskData.id} for transaction ${transaction.id}`);
      
      // Update transaction with task_id
      const { error: updateError } = await supabase
        .from('payment_transactions')
        .update({ task_id: taskData.id })
        .eq('id', transaction.id);
      
      if (updateError) {
        console.log(`❌ Error updating transaction ${transaction.id} with task_id:`, updateError);
      } else {
        console.log(`✅ Updated transaction ${transaction.id} with task_id ${taskData.id}`);
      }
      
      // Find accountant user to assign task
      const { data: accountant, error: accountantError } = await supabase
        .from('users')
        .select('id, name')
        .contains('role', ['accountant'])
        .eq('is_active', true)
        .limit(1)
        .single();
      
      if (!accountantError && accountant) {
        // Create task assignment
        const { error: assignmentError } = await supabase
          .from('task_assignments')
          .insert({
            task_id: taskData.id,
            assignment_type: 'user',
            assigned_by: 'system',
            assigned_by_name: 'Payment Automation Fix',
            assigned_by_role: 'system',
            assigned_to_user_id: accountant.id,
            status: 'active',
            notes: `Auto-assigned for payment processing of bill: ${transaction.bill_number}`
          });
        
        if (assignmentError) {
          console.log(`❌ Error creating assignment for task ${taskData.id}:`, assignmentError);
        } else {
          console.log(`✅ Assigned task ${taskData.id} to accountant ${accountant.name}`);
        }
      }
    }
    
    // 3. Remove auto-generated payment_reference values
    console.log('\n📋 Step 2: Removing auto-generated payment references...');
    const { data: paymentsWithAutoRef, error: autoRefError } = await supabase
      .from('vendor_payment_schedule')
      .select('id, bill_number, payment_reference')
      .like('payment_reference', 'AUTO-COD-%');
    
    if (autoRefError) {
      console.log('❌ Error fetching payments with auto references:', autoRefError);
    } else {
      console.log(`Found ${paymentsWithAutoRef.length} payments with auto-generated references`);
      
      for (const payment of paymentsWithAutoRef) {
        const { error: clearError } = await supabase
          .from('vendor_payment_schedule')
          .update({ payment_reference: null })
          .eq('id', payment.id);
        
        if (clearError) {
          console.log(`❌ Error clearing reference for payment ${payment.id}:`, clearError);
        } else {
          console.log(`✅ Cleared auto-reference for payment ${payment.bill_number}`);
        }
      }
    }
    
    // 4. Test trigger by temporarily updating a payment
    console.log('\n📋 Step 3: Testing trigger functionality...');
    
    // Find a paid payment to test with
    const { data: testPayment, error: testError } = await supabase
      .from('vendor_payment_schedule')
      .select('id, bill_number, is_paid')
      .eq('is_paid', true)
      .limit(1)
      .single();
    
    if (!testError && testPayment) {
      console.log(`🧪 Testing trigger with payment ${testPayment.bill_number}...`);
      
      // Temporarily set is_paid to false, then back to true to trigger the automation
      await supabase
        .from('vendor_payment_schedule')
        .update({ is_paid: false })
        .eq('id', testPayment.id);
      
      // Wait a moment
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Set back to true to trigger
      const { error: triggerError } = await supabase
        .from('vendor_payment_schedule')
        .update({ is_paid: true })
        .eq('id', testPayment.id);
      
      if (triggerError) {
        console.log('❌ Error testing trigger:', triggerError);
      } else {
        console.log('✅ Trigger test completed - check if new task was created');
      }
    }
    
    console.log('\n🎉 Payment automation fix completed!');
    
  } catch (error) {
    console.error('❌ Error during fix:', error);
  }
}

fixPaymentIssues();