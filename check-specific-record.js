// Check the specific receiving record that's failing
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkRecord() {
  const receivingRecordId = 'baa17e91-f812-4e07-a8d2-bb88580643b8';
  const taskId = '66b97904-7ccf-4d4d-a411-fa74aa987811';
  
  console.log('🔍 Checking receiving record:', receivingRecordId);
  console.log('🔍 Checking task:', taskId);
  
  // Check the receiving record
  const { data: record, error: recordError } = await supabase
    .from('receiving_records')
    .select('id, pr_excel_file_url, pr_excel_file_uploaded, erp_purchase_invoice_reference, erp_purchase_invoice_uploaded, original_bill_url, original_bill_uploaded, inventory_manager_user_id')
    .eq('id', receivingRecordId)
    .single();

  if (recordError) {
    console.log('❌ Error getting record:', recordError);
  } else {
    console.log('\n📦 Receiving Record Details:');
    console.log('   - pr_excel_file_url:', record.pr_excel_file_url);
    console.log('   - pr_excel_file_uploaded:', record.pr_excel_file_uploaded, record.pr_excel_file_uploaded ? '✓' : '✗');
    console.log('   - inventory_manager_user_id:', record.inventory_manager_user_id);
    console.log('   - erp_purchase_invoice_reference:', record.erp_purchase_invoice_reference);
    console.log('   - erp_purchase_invoice_uploaded:', record.erp_purchase_invoice_uploaded, record.erp_purchase_invoice_uploaded ? '✓' : '✗');
    console.log('   - original_bill_url:', record.original_bill_url);
    console.log('   - original_bill_uploaded:', record.original_bill_uploaded, record.original_bill_uploaded ? '✓' : '✗');

    // Check if this needs fixing
    const needsFix = 
      (record.pr_excel_file_url && !record.pr_excel_file_uploaded) ||
      (record.erp_purchase_invoice_reference && !record.erp_purchase_invoice_uploaded) ||
      (record.original_bill_url && !record.original_bill_uploaded);

    if (needsFix) {
      console.log('\n⚠️  FLAGS NEED FIXING!');
      
      // Fix the flags
      const updates = {};
      if (record.pr_excel_file_url && !record.pr_excel_file_uploaded) {
        updates.pr_excel_file_uploaded = true;
      }
      if (record.erp_purchase_invoice_reference && !record.erp_purchase_invoice_uploaded) {
        updates.erp_purchase_invoice_uploaded = true;
      }
      if (record.original_bill_url && !record.original_bill_uploaded) {
        updates.original_bill_uploaded = true;
      }

      console.log('\n🔧 Applying fixes:', updates);

      const { data: updated, error: updateError } = await supabase
        .from('receiving_records')
        .update(updates)
        .eq('id', receivingRecordId)
        .select()
        .single();

      if (updateError) {
        console.log('❌ Error updating:', updateError);
      } else {
        console.log('✅ Fixed! Updated record:', {
          pr_excel_file_uploaded: updated.pr_excel_file_uploaded,
          erp_purchase_invoice_uploaded: updated.erp_purchase_invoice_uploaded,
          original_bill_uploaded: updated.original_bill_uploaded
        });
      }
    } else {
      console.log('\n✅ All flags are correct!');
    }
  }

  // Check the task
  const { data: task, error: taskError } = await supabase
    .from('receiving_tasks')
    .select('*')
    .eq('id', taskId)
    .single();

  if (taskError) {
    console.log('\n❌ Error getting task:', taskError);
  } else {
    console.log('\n📋 Task Details:');
    console.log('   - role_type:', task.role_type);
    console.log('   - task_completed:', task.task_completed);
    console.log('   - requires_erp_reference:', task.requires_erp_reference);
    console.log('   - requires_original_bill_upload:', task.requires_original_bill_upload);
  }
}

checkRecord().catch(console.error);
