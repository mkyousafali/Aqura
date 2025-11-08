// Check the complete_receiving_task_simple function definition
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkFunction() {
  console.log('🔍 Checking complete_receiving_task_simple function...\n');

  // Get function definition
  const { data, error } = await supabase.rpc('pg_get_functiondef', {
    func_oid: "(SELECT oid FROM pg_proc WHERE proname = 'complete_receiving_task_simple')"
  });

  if (error) {
    console.error('❌ Error getting function:', error);
    
    // Try alternative method - query pg_proc directly
    console.log('\n🔍 Trying alternative method...\n');
    
    const { data: funcData, error: funcError } = await supabase
      .from('pg_proc')
      .select('*')
      .eq('proname', 'complete_receiving_task_simple')
      .single();
    
    if (funcError) {
      console.error('❌ Alternative method also failed:', funcError);
    } else {
      console.log('✅ Function info:', funcData);
    }
  } else {
    console.log('✅ Function definition:', data);
  }

  // Let's also check what validation errors the function can return
  console.log('\n🔍 Checking receiving_tasks table structure...\n');
  
  const { data: tableInfo, error: tableError } = await supabase
    .from('receiving_tasks')
    .select('*')
    .limit(1);
    
  if (tableError) {
    console.error('❌ Error:', tableError);
  } else {
    console.log('✅ Table columns:', Object.keys(tableInfo[0] || {}));
  }

  // Check receiving_records table
  console.log('\n🔍 Checking receiving_records table structure...\n');
  
  const { data: recordInfo, error: recordError } = await supabase
    .from('receiving_records')
    .select('*')
    .limit(1);
    
  if (recordError) {
    console.error('❌ Error:', recordError);
  } else {
    console.log('✅ Table columns:', Object.keys(recordInfo[0] || {}));
  }

  // Check the specific receiving record from the error
  console.log('\n🔍 Checking specific receiving record: 936acf71-6dfa-4355-a70d-77b89b0d72fd\n');
  
  const { data: specificRecord, error: specificError } = await supabase
    .from('receiving_records')
    .select('id, pr_excel_file_url, pr_excel_file_uploaded, erp_purchase_invoice_reference, erp_purchase_invoice_uploaded, original_bill_url, original_bill_uploaded')
    .eq('id', '936acf71-6dfa-4355-a70d-77b89b0d72fd')
    .single();
    
  if (specificError) {
    console.error('❌ Error:', specificError);
  } else {
    console.log('✅ Receiving Record Status:');
    console.log('   - pr_excel_file_url:', specificRecord.pr_excel_file_url ? 'Present' : 'NULL');
    console.log('   - pr_excel_file_uploaded:', specificRecord.pr_excel_file_uploaded);
    console.log('   - erp_purchase_invoice_reference:', specificRecord.erp_purchase_invoice_reference || 'NULL');
    console.log('   - erp_purchase_invoice_uploaded:', specificRecord.erp_purchase_invoice_uploaded);
    console.log('   - original_bill_url:', specificRecord.original_bill_url ? 'Present' : 'NULL');
    console.log('   - original_bill_uploaded:', specificRecord.original_bill_uploaded);
  }

  // Check vendor_payment_schedule
  console.log('\n🔍 Checking vendor_payment_schedule for this record...\n');
  
  const { data: paymentSchedule, error: paymentError } = await supabase
    .from('vendor_payment_schedule')
    .select('id, pr_excel_verified, pr_excel_verified_by, pr_excel_verified_date')
    .eq('receiving_record_id', '936acf71-6dfa-4355-a70d-77b89b0d72fd')
    .single();
    
  if (paymentError) {
    console.error('❌ Error:', paymentError);
  } else {
    console.log('✅ Payment Schedule Status:');
    console.log('   - pr_excel_verified:', paymentSchedule.pr_excel_verified);
    console.log('   - pr_excel_verified_by:', paymentSchedule.pr_excel_verified_by || 'NULL');
    console.log('   - pr_excel_verified_date:', paymentSchedule.pr_excel_verified_date || 'NULL');
  }
}

checkFunction().catch(console.error);
