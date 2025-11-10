// Fix the upload flags for the receiving record
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function fixFlags() {
  const receivingRecordId = '6c896a1e-afd7-45a1-b062-ae665864063b';
  
  console.log('🔧 Fixing upload flags for receiving record:', receivingRecordId);
  
  // Get current state
  const { data: before, error: beforeError } = await supabase
    .from('receiving_records')
    .select('id, pr_excel_file_url, pr_excel_file_uploaded, erp_purchase_invoice_reference, erp_purchase_invoice_uploaded, original_bill_url, original_bill_uploaded')
    .eq('id', receivingRecordId)
    .single();

  if (beforeError) {
    console.log('❌ Error getting record:', beforeError);
    return;
  }

  console.log('\n📋 BEFORE UPDATE:');
  console.log('   - pr_excel_file_url:', before.pr_excel_file_url);
  console.log('   - pr_excel_file_uploaded:', before.pr_excel_file_uploaded, before.pr_excel_file_uploaded ? '✓' : '✗');
  console.log('   - erp_purchase_invoice_reference:', before.erp_purchase_invoice_reference);
  console.log('   - erp_purchase_invoice_uploaded:', before.erp_purchase_invoice_uploaded, before.erp_purchase_invoice_uploaded ? '✓' : '✗');
  console.log('   - original_bill_url:', before.original_bill_url);
  console.log('   - original_bill_uploaded:', before.original_bill_uploaded, before.original_bill_uploaded ? '✓' : '✗');

  // Update the flags based on what files exist
  const updates = {};
  
  if (before.pr_excel_file_url && !before.pr_excel_file_uploaded) {
    updates.pr_excel_file_uploaded = true;
    console.log('\n✅ Setting pr_excel_file_uploaded = true');
  }
  
  if (before.erp_purchase_invoice_reference && !before.erp_purchase_invoice_uploaded) {
    updates.erp_purchase_invoice_uploaded = true;
    console.log('✅ Setting erp_purchase_invoice_uploaded = true');
  }
  
  if (before.original_bill_url && !before.original_bill_uploaded) {
    updates.original_bill_uploaded = true;
    console.log('✅ Setting original_bill_uploaded = true');
  }

  if (Object.keys(updates).length === 0) {
    console.log('\n✨ All flags are already correct!');
    return;
  }

  console.log('\n🔄 Applying updates:', updates);

  // Apply the update
  const { data: after, error: updateError } = await supabase
    .from('receiving_records')
    .update(updates)
    .eq('id', receivingRecordId)
    .select('id, pr_excel_file_url, pr_excel_file_uploaded, erp_purchase_invoice_reference, erp_purchase_invoice_uploaded, original_bill_url, original_bill_uploaded')
    .single();

  if (updateError) {
    console.log('❌ Error updating record:', updateError);
    return;
  }

  console.log('\n📋 AFTER UPDATE:');
  console.log('   - pr_excel_file_url:', after.pr_excel_file_url);
  console.log('   - pr_excel_file_uploaded:', after.pr_excel_file_uploaded, after.pr_excel_file_uploaded ? '✓' : '✗');
  console.log('   - erp_purchase_invoice_reference:', after.erp_purchase_invoice_reference);
  console.log('   - erp_purchase_invoice_uploaded:', after.erp_purchase_invoice_uploaded, after.erp_purchase_invoice_uploaded ? '✓' : '✗');
  console.log('   - original_bill_url:', after.original_bill_url);
  console.log('   - original_bill_uploaded:', after.original_bill_uploaded, after.original_bill_uploaded ? '✓' : '✗');

  console.log('\n✨ Flags fixed successfully! Purchase manager should now be able to complete the task.');
}

fixFlags().catch(console.error);
