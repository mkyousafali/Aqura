// Check the purchase manager task completion function in database
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkFunction() {
  console.log('🔍 Checking complete_receiving_task_simple function...\n');

  // Get the function definition
  const { data: funcDef, error: funcError } = await supabase
    .rpc('pg_get_functiondef', {
      func_oid: "(SELECT oid FROM pg_proc WHERE proname = 'complete_receiving_task_simple')"
    });

  if (funcError) {
    console.log('❌ Error getting function definition:', funcError);
    
    // Try alternative method
    console.log('\n📋 Trying alternative method to get function...\n');
    const { data: funcInfo, error: infoError } = await supabase
      .from('pg_proc')
      .select('*')
      .eq('proname', 'complete_receiving_task_simple')
      .single();
    
    if (infoError) {
      console.log('❌ Error getting function info:', infoError);
    } else {
      console.log('✅ Function info:', funcInfo);
    }
  } else {
    console.log('✅ Function definition:\n', funcDef);
  }

  // Check the receiving record that's causing the issue
  const receivingRecordId = '6c896a1e-afd7-45a1-b062-ae665864063b';
  console.log('\n\n📦 Checking receiving record:', receivingRecordId);
  
  const { data: record, error: recordError } = await supabase
    .from('receiving_records')
    .select('id, pr_excel_file_url, pr_excel_file_uploaded, erp_purchase_invoice_reference, erp_purchase_invoice_uploaded, original_bill_url, original_bill_uploaded, inventory_manager_user_id')
    .eq('id', receivingRecordId)
    .single();

  if (recordError) {
    console.log('❌ Error getting record:', recordError);
  } else {
    console.log('✅ Receiving Record Details:');
    console.log('   - pr_excel_file_url:', record.pr_excel_file_url);
    console.log('   - pr_excel_file_uploaded:', record.pr_excel_file_uploaded);
    console.log('   - inventory_manager_user_id:', record.inventory_manager_user_id);
    console.log('   - erp_purchase_invoice_reference:', record.erp_purchase_invoice_reference);
    console.log('   - erp_purchase_invoice_uploaded:', record.erp_purchase_invoice_uploaded);
    console.log('   - original_bill_url:', record.original_bill_url);
    console.log('   - original_bill_uploaded:', record.original_bill_uploaded);
  }

  // Check the task
  const taskId = '5d0bf3a0-3d9d-40bc-8082-1d17e79dc635';
  console.log('\n\n📋 Checking receiving task:', taskId);
  
  const { data: task, error: taskError } = await supabase
    .from('receiving_tasks')
    .select('*')
    .eq('id', taskId)
    .single();

  if (taskError) {
    console.log('❌ Error getting task:', taskError);
  } else {
    console.log('✅ Task Details:');
    console.log('   - role_type:', task.role_type);
    console.log('   - task_completed:', task.task_completed);
    console.log('   - requires_erp_reference:', task.requires_erp_reference);
    console.log('   - requires_original_bill_upload:', task.requires_original_bill_upload);
  }

  // Try to execute a query to see what the function checks
  console.log('\n\n🔍 Executing raw SQL to check function logic...\n');
  
  const { data: sqlResult, error: sqlError } = await supabase.rpc('exec_sql', {
    query: `
      SELECT 
        proname,
        prosrc
      FROM pg_proc 
      WHERE proname = 'complete_receiving_task_simple'
    `
  });

  if (sqlError) {
    console.log('❌ Error executing SQL:', sqlError);
  } else {
    console.log('✅ SQL Result:', sqlResult);
  }
}

checkFunction().catch(console.error);
