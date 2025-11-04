const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function testDifferentApproaches() {
  console.log('🔬 TESTING DIFFERENT ROUNDING APPROACHES\n');
  console.log('='.repeat(80));

  const testPaymentId = 'af500080-2d7e-42b7-aa7b-adee12770047';
  
  try {
    const { data: payment } = await supabase
      .from('vendor_payment_schedule')
      .select('*')
      .eq('id', testPaymentId)
      .single();

    const billAmount = 22401.25;
    const grrAmount = 11837.30;

    console.log('📊 Testing different calculation methods:\n');

    // Method 1: Direct subtraction (current, fails)
    const method1 = billAmount - grrAmount;
    console.log(`Method 1 (Direct subtraction):`);
    console.log(`  ${billAmount} - ${grrAmount} = ${method1}`);
    console.log(`  Precision: ${method1.toFixed(20)}`);

    // Method 2: Round result
    const method2 = Math.round((billAmount - grrAmount) * 100) / 100;
    console.log(`\nMethod 2 (Round result):`);
    console.log(`  Math.round((${billAmount} - ${grrAmount}) * 100) / 100 = ${method2}`);
    console.log(`  Precision: ${method2.toFixed(20)}`);

    // Method 3: Convert to cents, calculate, convert back
    const method3 = (Math.round(billAmount * 100) - Math.round(grrAmount * 100)) / 100;
    console.log(`\nMethod 3 (Cent arithmetic):`);
    console.log(`  (round(${billAmount}*100) - round(${grrAmount}*100)) / 100 = ${method3}`);
    console.log(`  Precision: ${method3.toFixed(20)}`);

    // Method 4: toFixed and parseFloat
    const method4 = parseFloat((billAmount - grrAmount).toFixed(2));
    console.log(`\nMethod 4 (toFixed + parseFloat):`);
    console.log(`  parseFloat((${billAmount} - ${grrAmount}).toFixed(2)) = ${method4}`);
    console.log(`  Precision: ${method4.toFixed(20)}`);

    // Method 5: String manipulation
    const method5Str = (billAmount - grrAmount).toFixed(2);
    const method5 = parseFloat(method5Str);
    console.log(`\nMethod 5 (String via toFixed):`);
    console.log(`  String: "${method5Str}"`);
    console.log(`  Parsed: ${method5}`);
    console.log(`  Precision: ${method5.toFixed(20)}`);

    // Now test Method 3 (cent arithmetic) in database
    console.log('\n\n🧪 TESTING METHOD 3 (CENT ARITHMETIC) IN DATABASE:');
    console.log('='.repeat(80));

    const billCents = Math.round(billAmount * 100);
    const grrCents = Math.round(grrAmount * 100);
    const finalCents = billCents - grrCents;
    const finalAmount = finalCents / 100;

    console.log(`\nCalculation in cents:`);
    console.log(`  Bill: ${billAmount} → ${billCents} cents`);
    console.log(`  GRR: ${grrAmount} → ${grrCents} cents`);
    console.log(`  Final: ${finalCents} cents → ${finalAmount}`);
    console.log(`  Precision: ${finalAmount.toFixed(20)}`);

    const { data, error } = await supabase
      .from('vendor_payment_schedule')
      .update({
        grr_amount: grrAmount,
        discount_amount: 0,
        pri_amount: 0,
        final_bill_amount: finalAmount,
        updated_at: new Date().toISOString()
      })
      .eq('id', testPaymentId)
      .select();

    if (error) {
      console.log(`\n❌ UPDATE FAILED:`);
      console.log(`   Error: ${error.message}`);
      
      // Maybe the constraint checks in cents?
      console.log('\n💡 Maybe the constraint checks for integer cents?');
      console.log(`   Bill (cents): ${billCents}`);
      console.log(`   Final (cents): ${finalCents}`);
      console.log(`   GRR (cents): ${grrCents}`);
      console.log(`   Equation: ${billCents} - ${grrCents} = ${finalCents} ✅`);
      
    } else {
      console.log(`\n✅ UPDATE SUCCEEDED!`);
      console.log(`   New final_bill_amount: ${data[0].final_bill_amount}`);
    }

    // Test if maybe we need to use NUMERIC type
    console.log('\n\n🔍 HYPOTHESIS: Constraint uses NUMERIC/DECIMAL comparison');
    console.log('='.repeat(80));
    console.log('PostgreSQL NUMERIC type stores exact decimal values');
    console.log('The constraint might be comparing NUMERIC values, not FLOAT');
    console.log('\nIn PostgreSQL:');
    console.log(`  22401.25::numeric - 11837.30::numeric = 10563.95::numeric (exact)`);
    console.log(`  But JavaScript sends: 10563.95000000000072759576`);
    console.log('  Which gets truncated/rounded by PostgreSQL to: 10563.95');
    console.log('  But the constraint check happens BEFORE the truncation!');

  } catch (error) {
    console.error('❌ Error:', error);
  }
}

testDifferentApproaches()
  .then(() => {
    console.log('\n\n✅ Analysis complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });
