const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function testCentArithmetic() {
  console.log('🎯 TESTING CENT-BASED ARITHMETIC (FINAL FIX)\n');
  console.log('='.repeat(80));

  const testPaymentId = 'af500080-2d7e-42b7-aa7b-adee12770047';
  
  try {
    // The problematic values
    const billAmount = 22401.25;
    const grrAmount = 11837.30;
    const discountAmount = 0;
    const priAmount = 0;

    // Calculate in CENTS (integer arithmetic - EXACT)
    const billCents = Math.round(billAmount * 100);
    const grrCents = Math.round(grrAmount * 100);
    const discountCents = Math.round(discountAmount * 100);
    const priCents = Math.round(priAmount * 100);
    
    // Integer subtraction (exact)
    const finalCents = billCents - grrCents - discountCents - priCents;
    
    // Convert back to dollars
    const finalAmount = finalCents / 100;

    console.log('📊 CENT-BASED CALCULATION:');
    console.log(`  Bill: ${billAmount} → ${billCents} cents`);
    console.log(`  GRR: ${grrAmount} → ${grrCents} cents`);
    console.log(`  Discount: ${discountAmount} → ${discountCents} cents`);
    console.log(`  PRI: ${priAmount} → ${priCents} cents`);
    console.log(`  \n  Calculation: ${billCents} - ${grrCents} - ${discountCents} - ${priCents} = ${finalCents} cents`);
    console.log(`  Final Amount: ${finalAmount}`);
    console.log(`  Full Precision: ${finalAmount.toFixed(20)}`);

    console.log('\n\n🧪 ATTEMPTING DATABASE UPDATE:');
    console.log('='.repeat(80));

    const { data, error } = await supabase
      .from('vendor_payment_schedule')
      .update({
        discount_amount: discountAmount,
        grr_amount: grrAmount,
        pri_amount: priAmount,
        final_bill_amount: finalAmount,
        last_adjustment_date: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', testPaymentId)
      .select();

    if (error) {
      console.log('\n❌ UPDATE FAILED:');
      console.log(`   Error: ${error.message}`);
      console.log(`   Code: ${error.code}`);
      
      console.log('\n🔍 THE CONSTRAINT MUST BE DOING ITS OWN CALCULATION');
      console.log('   PostgreSQL is likely recalculating:');
      console.log(`     ${billAmount}::numeric - ${grrAmount}::numeric - ${discountAmount}::numeric - ${priAmount}::numeric`);
      console.log('   And comparing it to our sent final_bill_amount');
      console.log('   \n   The issue: Even with cent arithmetic, when we divide by 100,');
      console.log('   we get the SAME floating-point representation in JavaScript!');
      console.log(`   \n   ${finalCents} / 100 = ${finalAmount} (JS float)`);
      console.log(`   But PostgreSQL::numeric = 10563.95 (exact decimal)`);
      
    } else {
      console.log('\n✅✅✅ UPDATE SUCCEEDED! ✅✅✅');
      console.log(`   New final_bill_amount: ${data[0].final_bill_amount}`);
      console.log(`   New grr_amount: ${data[0].grr_amount}`);
      console.log(`   Updated at: ${data[0].updated_at}`);
      
      console.log('\n🎉 SOLUTION CONFIRMED:');
      console.log('   Integer cent arithmetic avoids floating-point errors!');
      console.log('   The division by 100 produces a clean result that matches PostgreSQL NUMERIC.');
    }

  } catch (error) {
    console.error('\n❌ UNEXPECTED ERROR:', error);
  }
}

testCentArithmetic()
  .then(() => {
    console.log('\n\n✅ Test complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n❌ Fatal error:', error);
    process.exit(1);
  });
