// Find and fix all receiving records with mismatched upload flags
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function findAndFixAll() {
  console.log('🔍 Searching for receiving records with mismatched upload flags...\n');

  // Get all receiving records
  const { data: records, error } = await supabase
    .from('receiving_records')
    .select('id, pr_excel_file_url, pr_excel_file_uploaded, original_bill_url, original_bill_uploaded, erp_purchase_invoice_reference, erp_purchase_invoice_uploaded')
    .order('created_at', { ascending: false })
    .limit(1000);

  if (error) {
    console.error('❌ Error fetching records:', error);
    return;
  }

  console.log(`📊 Found ${records.length} receiving records\n`);

  // Find records with mismatches
  const mismatches = records.filter(record => {
    const prExcelMismatch = record.pr_excel_file_url && !record.pr_excel_file_uploaded;
    const originalBillMismatch = record.original_bill_url && !record.original_bill_uploaded;
    const erpReferenceMismatch = record.erp_purchase_invoice_reference && !record.erp_purchase_invoice_uploaded;
    
    return prExcelMismatch || originalBillMismatch || erpReferenceMismatch;
  });

  if (mismatches.length === 0) {
    console.log('✅ No mismatches found! All records are properly flagged.\n');
    return;
  }

  console.log(`⚠️  Found ${mismatches.length} records with mismatched flags:\n`);

  for (const record of mismatches) {
    console.log(`📝 Record ID: ${record.id}`);
    
    const issues = [];
    if (record.pr_excel_file_url && !record.pr_excel_file_uploaded) {
      issues.push('   ❌ PR Excel file uploaded but flag is false');
    }
    if (record.original_bill_url && !record.original_bill_uploaded) {
      issues.push('   ❌ Original bill uploaded but flag is false');
    }
    if (record.erp_purchase_invoice_reference && !record.erp_purchase_invoice_uploaded) {
      issues.push('   ❌ ERP reference exists but flag is false');
    }
    
    console.log(issues.join('\n'));
    console.log('');
  }

  // Ask for confirmation before fixing
  console.log(`\n🔧 Fixing ${mismatches.length} records...\n`);

  let fixedCount = 0;
  let errorCount = 0;

  for (const record of mismatches) {
    const updates = {};
    
    if (record.pr_excel_file_url && !record.pr_excel_file_uploaded) {
      updates.pr_excel_file_uploaded = true;
    }
    
    if (record.original_bill_url && !record.original_bill_uploaded) {
      updates.original_bill_uploaded = true;
    }
    
    if (record.erp_purchase_invoice_reference && !record.erp_purchase_invoice_uploaded) {
      updates.erp_purchase_invoice_uploaded = true;
    }

    if (Object.keys(updates).length > 0) {
      const { error: updateError } = await supabase
        .from('receiving_records')
        .update(updates)
        .eq('id', record.id);

      if (updateError) {
        console.error(`❌ Failed to fix ${record.id}:`, updateError.message);
        errorCount++;
      } else {
        console.log(`✅ Fixed ${record.id} - Updated: ${Object.keys(updates).join(', ')}`);
        fixedCount++;
      }
    }
  }

  console.log(`\n📊 Summary:`);
  console.log(`   ✅ Successfully fixed: ${fixedCount} records`);
  if (errorCount > 0) {
    console.log(`   ❌ Failed to fix: ${errorCount} records`);
  }
  console.log('\n🎉 Fix complete!');
}

findAndFixAll().catch(console.error);
