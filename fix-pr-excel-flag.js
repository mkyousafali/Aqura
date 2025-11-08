// Fix the pr_excel_file_uploaded flag for the specific receiving record
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function fixRecord() {
  const recordId = '936acf71-6dfa-4355-a70d-77b89b0d72fd';
  
  console.log('🔧 Fixing pr_excel_file_uploaded flag...\n');

  // First, verify the current state
  const { data: before, error: beforeError } = await supabase
    .from('receiving_records')
    .select('id, pr_excel_file_url, pr_excel_file_uploaded, original_bill_url, original_bill_uploaded, erp_purchase_invoice_reference, erp_purchase_invoice_uploaded')
    .eq('id', recordId)
    .single();

  if (beforeError) {
    console.error('❌ Error fetching record:', beforeError);
    return;
  }

  console.log('📊 Current state:');
  console.log('   - pr_excel_file_url:', before.pr_excel_file_url ? 'Present ✓' : 'NULL ✗');
  console.log('   - pr_excel_file_uploaded:', before.pr_excel_file_uploaded, before.pr_excel_file_uploaded ? '✓' : '✗');
  console.log('   - original_bill_url:', before.original_bill_url ? 'Present ✓' : 'NULL ✗');
  console.log('   - original_bill_uploaded:', before.original_bill_uploaded, before.original_bill_uploaded ? '✓' : '✗');
  console.log('   - erp_purchase_invoice_reference:', before.erp_purchase_invoice_reference ? 'Present ✓' : 'NULL ✗');
  console.log('   - erp_purchase_invoice_uploaded:', before.erp_purchase_invoice_uploaded, before.erp_purchase_invoice_uploaded ? '✓' : '✗');

  // Update the flags based on what's actually uploaded
  const updates = {};
  
  if (before.pr_excel_file_url && !before.pr_excel_file_uploaded) {
    updates.pr_excel_file_uploaded = true;
    console.log('\n🔧 Setting pr_excel_file_uploaded = true');
  }
  
  if (before.original_bill_url && !before.original_bill_uploaded) {
    updates.original_bill_uploaded = true;
    console.log('🔧 Setting original_bill_uploaded = true');
  }
  
  if (before.erp_purchase_invoice_reference && !before.erp_purchase_invoice_uploaded) {
    updates.erp_purchase_invoice_uploaded = true;
    console.log('🔧 Setting erp_purchase_invoice_uploaded = true');
  }

  if (Object.keys(updates).length === 0) {
    console.log('\n✅ No updates needed - all flags are already correct!');
    return;
  }

  // Apply the updates
  const { data: after, error: updateError } = await supabase
    .from('receiving_records')
    .update(updates)
    .eq('id', recordId)
    .select('id, pr_excel_file_url, pr_excel_file_uploaded, original_bill_url, original_bill_uploaded, erp_purchase_invoice_reference, erp_purchase_invoice_uploaded')
    .single();

  if (updateError) {
    console.error('\n❌ Error updating record:', updateError);
    return;
  }

  console.log('\n✅ Successfully updated! New state:');
  console.log('   - pr_excel_file_url:', after.pr_excel_file_url ? 'Present ✓' : 'NULL ✗');
  console.log('   - pr_excel_file_uploaded:', after.pr_excel_file_uploaded, after.pr_excel_file_uploaded ? '✓' : '✗');
  console.log('   - original_bill_url:', after.original_bill_url ? 'Present ✓' : 'NULL ✗');
  console.log('   - original_bill_uploaded:', after.original_bill_uploaded, after.original_bill_uploaded ? '✓' : '✗');
  console.log('   - erp_purchase_invoice_reference:', after.erp_purchase_invoice_reference ? 'Present ✓' : 'NULL ✗');
  console.log('   - erp_purchase_invoice_uploaded:', after.erp_purchase_invoice_uploaded, after.erp_purchase_invoice_uploaded ? '✓' : '✗');

  console.log('\n🎉 Fix complete! You can now complete the Purchase Manager task.');
}

fixRecord().catch(console.error);
