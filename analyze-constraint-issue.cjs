const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function analyzeConstraintIssue() {
  console.log('🔍 ANALYZING: The real constraint issue\n');
  console.log('='.repeat(80));

  const testPaymentId = 'af500080-2d7e-42b7-aa7b-adee12770047';

  try {
    // Get current record values
    const { data: current } = await supabase
      .from('vendor_payment_schedule')
      .select('bill_amount, original_final_amount, final_bill_amount, discount_amount, grr_amount, pri_amount')
      .eq('id', testPaymentId)
      .single();

    console.log('📊 CURRENT VALUES:');
    console.log(`  bill_amount: ${current.bill_amount}`);
    console.log(`  original_final_amount: ${current.original_final_amount}`);
    console.log(`  final_bill_amount: ${current.final_bill_amount}`);
    console.log(`  discount_amount: ${current.discount_amount}`);
    console.log(`  grr_amount: ${current.grr_amount}`);
    console.log(`  pri_amount: ${current.pri_amount}`);

    // Analyze the constraint
    console.log('\n🔍 CONSTRAINT ANALYSIS:');
    console.log('The constraint checks: total_deductions <= COALESCE(original_final_amount, final_bill_amount, bill_amount)');
    
    const referenceAmount = current.original_final_amount || current.final_bill_amount || current.bill_amount;
    console.log(`  Reference amount: ${referenceAmount}`);
    
    const currentDeductions = (current.discount_amount || 0) + (current.grr_amount || 0) + (current.pri_amount || 0);
    console.log(`  Current total deductions: ${currentDeductions}`);
    
    const proposedDeductions = 11837.30; // Our test GRR amount
    console.log(`  Proposed GRR deduction: ${proposedDeductions}`);
    console.log(`  Constraint check: ${proposedDeductions} <= ${referenceAmount} = ${proposedDeductions <= referenceAmount}`);

    if (proposedDeductions > referenceAmount) {
      console.log('\n❌ PROBLEM IDENTIFIED:');
      console.log(`  The GRR amount (${proposedDeductions}) exceeds the reference amount (${referenceAmount})`);
      console.log('  This is a business logic issue, not a floating-point precision issue!');
      
      console.log('\n💡 SOLUTIONS:');
      console.log('  1. Check if original_final_amount should be updated');
      console.log('  2. Verify the GRR amount is correct');
      console.log('  3. Update the reference amount if needed');
    } else {
      console.log('\n✅ CONSTRAINT SHOULD PASS:');
      console.log('  The deduction amount is within limits');
      
      // Test what happens if we try the update
      console.log('\n🧪 TESTING: Direct update with correct constraint understanding');
      
      // Reset to clean state first
      await supabase
        .from('vendor_payment_schedule')
        .update({ 
          discount_amount: null,
          grr_amount: null,
          pri_amount: null,
          final_bill_amount: current.bill_amount // Reset to original
        })
        .eq('id', testPaymentId);

      // Now try the update knowing the constraint
      const { error: testError } = await supabase
        .from('vendor_payment_schedule')
        .update({ 
          grr_amount: 11837.30,
          final_bill_amount: current.bill_amount - 11837.30 // Calculate final amount
        })
        .eq('id', testPaymentId);

      if (testError) {
        console.log(`❌ Still failed: ${testError.message}`);
        console.log('There might be another issue or the constraint is more complex');
      } else {
        console.log('✅ Update succeeded with correct constraint understanding!');
      }
    }

    // Additional investigation: check if original_final_amount is the issue
    if (current.original_final_amount && current.original_final_amount < current.bill_amount) {
      console.log('\n⚠️ POTENTIAL ISSUE FOUND:');
      console.log(`  original_final_amount (${current.original_final_amount}) < bill_amount (${current.bill_amount})`);
      console.log('  The constraint uses original_final_amount as the limit, which might be too restrictive');
      
      console.log('\n🔧 POSSIBLE FIX:');
      console.log('  Update original_final_amount to match bill_amount, or');
      console.log('  Modify the constraint to use bill_amount instead');
    }

  } catch (error) {
    console.error('❌ Error:', error);
  }
}

analyzeConstraintIssue()
  .then(() => {
    console.log('\n✅ Analysis complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });