const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function testFinalFix() {
  console.log('🎯 FINAL FIX TEST: Using toFixed() for exact decimal representation\n');
  console.log('='.repeat(80));

  const testPaymentId = 'af500080-2d7e-42b7-aa7b-adee12770047';
  
  try {
    // The problematic values
    const billAmount = 22401.25;
    const grrAmount = 11837.30;
    const discountAmount = 0;
    const priAmount = 0;

    // Calculate the final amount
    const rawFinal = billAmount - grrAmount - discountAmount - priAmount;
    
    // Convert to exact decimal string representation
    const finalAmountString = rawFinal.toFixed(2);
    const grrAmountString = grrAmount.toFixed(2);
    const discountAmountString = discountAmount.toFixed(2);
    const priAmountString = priAmount.toFixed(2);

    console.log('📊 VALUES PREPARATION:');
    console.log(`  Raw calculation: ${rawFinal}`);
    console.log(`  Raw precision: ${rawFinal.toFixed(20)}`);
    console.log(`  \n  Converted to strings (toFixed(2)):`);
    console.log(`    final_bill_amount: "${finalAmountString}"`);
    console.log(`    grr_amount: "${grrAmountString}"`);
    console.log(`    discount_amount: "${discountAmountString}"`);
    console.log(`    pri_amount: "${priAmountString}"`);
    console.log(`  \n  Parse back to float:`);
    console.log(`    parseFloat("${finalAmountString}") = ${parseFloat(finalAmountString)}`);
    console.log(`    Precision: ${parseFloat(finalAmountString).toFixed(20)}`);

    console.log('\n\n🧪 ATTEMPTING DATABASE UPDATE:');
    console.log('='.repeat(80));

    const { data, error } = await supabase
      .from('vendor_payment_schedule')
      .update({
        discount_amount: parseFloat(discountAmountString),
        grr_amount: parseFloat(grrAmountString),
        pri_amount: parseFloat(priAmountString),
        final_bill_amount: parseFloat(finalAmountString),
        last_adjustment_date: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', testPaymentId)
      .select();

    if (error) {
      console.log('\n❌ UPDATE STILL FAILED:');
      console.log(`   Error: ${error.message}`);
      console.log(`   Code: ${error.code}`);
      
      console.log('\n🔍 DEEPER INVESTIGATION NEEDED:');
      console.log('   The constraint might be defined as:');
      console.log('   CHECK (final_bill_amount = bill_amount - COALESCE(discount_amount, 0) - COALESCE(grr_amount, 0) - COALESCE(pri_amount, 0))');
      console.log('   \n   And PostgreSQL might be doing the calculation with its own precision');
      console.log('   which differs from JavaScript floating-point arithmetic.');
      
      console.log('\n💡 SOLUTION: We need to see the actual constraint definition');
      console.log('   Or modify the constraint to use ABS(difference) < 0.01 instead of exact equality');
      
    } else {
      console.log('\n✅ UPDATE SUCCEEDED!');
      console.log(`   New final_bill_amount: ${data[0].final_bill_amount}`);
      console.log(`   New grr_amount: ${data[0].grr_amount}`);
      console.log(`   Updated at: ${data[0].updated_at}`);
      
      // Verify
      console.log('\n🔍 VERIFICATION:');
      const stored = data[0];
      const verifyCalc = stored.bill_amount - (stored.discount_amount || 0) - (stored.grr_amount || 0) - (stored.pri_amount || 0);
      console.log(`   Stored final: ${stored.final_bill_amount}`);
      console.log(`   Calculated: ${verifyCalc}`);
      console.log(`   Match: ${Math.abs(stored.final_bill_amount - verifyCalc) < 0.01 ? '✅' : '❌'}`);
    }

  } catch (error) {
    console.error('\n❌ UNEXPECTED ERROR:', error);
  }
}

testFinalFix()
  .then(() => {
    console.log('\n\n✅ Test complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n❌ Fatal error:', error);
    process.exit(1);
  });
