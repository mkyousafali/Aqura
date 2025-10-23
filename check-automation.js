import { createClient } from '@supabase/supabase-js';

// Supabase configuration
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function checkAutomationStatus() {
  console.log('🔍 Checking automation status...');
  
  try {
    // Check if the trigger exists
    const { data: triggers, error: triggerError } = await supabase
      .from('information_schema.triggers')
      .select('*')
      .eq('trigger_name', 'trigger_auto_create_payment_transaction_and_task');
    
    if (triggerError) {
      console.log('❌ Error checking triggers:', triggerError);
    } else {
      console.log(`📋 Found ${triggers?.length || 0} matching triggers`);
      if (triggers && triggers.length > 0) {
        console.log('✅ Trigger exists:', triggers[0]);
      }
    }
    
    // Check if the function exists
    const { data: functions, error: functionError } = await supabase
      .from('information_schema.routines')
      .select('*')
      .eq('routine_name', 'auto_create_payment_transaction_and_task');
    
    if (functionError) {
      console.log('❌ Error checking functions:', functionError);
    } else {
      console.log(`📋 Found ${functions?.length || 0} matching functions`);
      if (functions && functions.length > 0) {
        console.log('✅ Function exists:', functions[0].routine_name);
      }
    }
    
    // Check recent paid payments and their status
    const { data: paidPayments, error: paymentsError } = await supabase
      .from('vendor_payment_schedule')
      .select(`
        id,
        is_paid,
        paid_date,
        bill_number,
        vendor_name,
        final_bill_amount,
        payment_reference,
        created_at,
        updated_at
      `)
      .eq('is_paid', true)
      .order('updated_at', { ascending: false })
      .limit(5);
    
    if (paymentsError) {
      console.log('❌ Error fetching paid payments:', paymentsError);
    } else {
      console.log(`📋 Recent paid payments (${paidPayments?.length || 0}):`);
      paidPayments?.forEach(payment => {
        console.log(`  - ${payment.bill_number}: ${payment.vendor_name} - ${payment.final_bill_amount} SAR`);
        console.log(`    Payment Reference: ${payment.payment_reference || 'NULL'}`);
        console.log(`    Paid Date: ${payment.paid_date || 'NULL'}`);
        console.log(`    Updated: ${payment.updated_at}`);
      });
    }
    
    // Check if these payments have corresponding tasks
    const { data: tasks, error: tasksError } = await supabase
      .from('tasks')
      .select(`
        id,
        title,
        description,
        status,
        created_by,
        created_at
      `)
      .like('title', '%Payment Processing%')
      .order('created_at', { ascending: false })
      .limit(10);
    
    if (tasksError) {
      console.log('❌ Error fetching tasks:', tasksError);
    } else {
      console.log(`📋 Recent payment tasks (${tasks?.length || 0}):`);
      tasks?.forEach(task => {
        console.log(`  - ${task.title} (${task.status}) - Created: ${task.created_at?.substring(0, 19)}`);
      });
    }
    
    // Check payment transactions
    const { data: transactions, error: transactionsError } = await supabase
      .from('payment_transactions')
      .select(`
        id,
        payment_schedule_id,
        task_id,
        amount,
        vendor_name,
        bill_number,
        verification_status,
        created_at
      `)
      .order('created_at', { ascending: false })
      .limit(10);
    
    if (transactionsError) {
      console.log('❌ Error fetching transactions:', transactionsError);
    } else {
      console.log(`📋 Recent payment transactions (${transactions?.length || 0}):`);
      transactions?.forEach(transaction => {
        console.log(`  - ${transaction.bill_number}: ${transaction.vendor_name} - ${transaction.amount} SAR`);
        console.log(`    Task ID: ${transaction.task_id || 'NULL'}`);
        console.log(`    Status: ${transaction.verification_status}`);
      });
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

checkAutomationStatus();