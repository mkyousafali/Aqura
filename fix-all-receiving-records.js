// Fix ALL receiving records with incorrect upload flags
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function fixAllRecords() {
  console.log('🔧 Fixing ALL receiving records with incorrect upload flags...\n');

  // Get all receiving records
  const { data: records, error } = await supabase
    .from('receiving_records')
    .select('id, pr_excel_file_url, pr_excel_file_uploaded, erp_purchase_invoice_reference, erp_purchase_invoice_uploaded, original_bill_url, original_bill_uploaded');

  if (error) {
    console.log('❌ Error fetching records:', error);
    return;
  }

  console.log(`📊 Found ${records.length} total records\n`);

  // Find records that need fixing
  const recordsNeedingFix = records.filter(record => {
    return (
      (record.pr_excel_file_url && !record.pr_excel_file_uploaded) ||
      (record.erp_purchase_invoice_reference && !record.erp_purchase_invoice_uploaded) ||
      (record.original_bill_url && !record.original_bill_uploaded)
    );
  });

  console.log(`⚠️  Found ${recordsNeedingFix.length} records needing fixes\n`);

  if (recordsNeedingFix.length === 0) {
    console.log('✅ All records are already correct!');
    return;
  }

  let fixedCount = 0;
  let errorCount = 0;

  // Fix each record
  for (const record of recordsNeedingFix) {
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

    console.log(`🔧 Fixing record ${record.id.substring(0, 8)}... (${Object.keys(updates).length} flags)`);

    const { error: updateError } = await supabase
      .from('receiving_records')
      .update(updates)
      .eq('id', record.id);

    if (updateError) {
      console.log(`   ❌ Error: ${updateError.message}`);
      errorCount++;
    } else {
      console.log(`   ✅ Fixed`);
      fixedCount++;
    }
  }

  console.log(`\n📊 Summary:`);
  console.log(`   ✅ Fixed: ${fixedCount} records`);
  console.log(`   ❌ Errors: ${errorCount} records`);
  console.log(`\n✨ All receiving records have been updated!`);
}

fixAllRecords().catch(console.error);
