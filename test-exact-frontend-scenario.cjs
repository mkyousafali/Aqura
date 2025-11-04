const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function testExactFrontendScenario() {
  console.log('🎯 TESTING EXACT FRONTEND SCENARIO\n');
  console.log('='.repeat(80));

  const testPaymentId = 'af500080-2d7e-42b7-aa7b-adee12770047';
  
  try {
    // Get current payment
    const { data: payment, error: fetchError } = await supabase
      .from('vendor_payment_schedule')
      .select('*')
      .eq('id', testPaymentId)
      .single();

    if (fetchError) {
      console.error('❌ Error fetching payment:', fetchError.message);
      return;
    }

    console.log('💳 Current Payment:');
    console.log(`  Bill Amount: ${payment.bill_amount}`);
    console.log(`  Current Final: ${payment.final_bill_amount}`);
    console.log(`  Current GRR: ${payment.grr_amount || 0}`);

    // SIMULATE EXACT FRONTEND CALCULATION (your fix)
    const editingAmountPayment = payment;
    const discountAmount = 0;  // From form
    const grrAmount = 11837.30; // From form (the problematic value)
    const priAmount = 0;       // From form

    // YOUR FIX: Calculate in cents + toFixed
    const billCents = Math.round(editingAmountPayment.bill_amount * 100);
    const discountCents = Math.round(discountAmount * 100);
    const grrCents = Math.round(grrAmount * 100);
    const priCents = Math.round(priAmount * 100);
    const finalCents = billCents - discountCents - grrCents - priCents;
    
    // Convert to decimal string with exactly 2 places
    const finalAmountStr = (finalCents / 100).toFixed(2);

    console.log('\n🔧 FRONTEND CALCULATION (YOUR FIX):');
    console.log(`  Bill: ${editingAmountPayment.bill_amount} → ${billCents} cents`);
    console.log(`  Discount: ${discountAmount} → ${discountCents} cents`);
    console.log(`  GRR: ${grrAmount} → ${grrCents} cents`);
    console.log(`  PRI: ${priAmount} → ${priCents} cents`);
    console.log(`  Final: ${finalCents} cents → "${finalAmountStr}"`);
    console.log(`  parseFloat result: ${parseFloat(finalAmountStr)}`);

    console.log('\n\n🧪 ATTEMPTING FRONTEND-STYLE UPDATE:');
    console.log('='.repeat(80));

    // Simulate the exact update the frontend would make
    const updateData = {
      final_bill_amount: parseFloat(finalAmountStr),
      discount_amount: discountAmount,
      grr_amount: grrAmount,
      pri_amount: priAmount,
      discount_notes: null,
      grr_reference_number: '1234',
      grr_notes: null,
      pri_reference_number: null,
      pri_notes: null,
      last_adjustment_date: new Date().toISOString(),
      last_adjusted_by: 'b658eca1-3cc1-48b2-bd3c-33b81fab5a0f', // Assuming current user
      adjustment_history: payment.adjustment_history || [],
      updated_at: new Date().toISOString()
    };

    console.log('📤 Sending update data:');
    console.log(JSON.stringify(updateData, null, 2));

    const { data, error } = await supabase
      .from('vendor_payment_schedule')
      .update(updateData)
      .eq('id', testPaymentId)
      .select();

    if (error) {
      console.log('\n❌ UPDATE STILL FAILED:');
      console.log(`   Error: ${error.message}`);
      console.log(`   Code: ${error.code}`);
      
      // Let's try a different approach - maybe the constraint includes null handling
      console.log('\n🔍 TRYING WITH EXPLICIT NULL HANDLING:');
      
      const alternativeData = {
        final_bill_amount: parseFloat(finalAmountStr),
        discount_amount: discountAmount || 0,
        grr_amount: grrAmount || 0,
        pri_amount: priAmount || 0,
        updated_at: new Date().toISOString()
      };

      const { data: altData, error: altError } = await supabase
        .from('vendor_payment_schedule')
        .update(alternativeData)
        .eq('id', testPaymentId)
        .select();

      if (altError) {
        console.log(`\n❌ ALTERNATIVE APPROACH ALSO FAILED: ${altError.message}`);
        
        // Last resort: try not updating final_bill_amount at all
        console.log('\n🔍 TRYING WITHOUT final_bill_amount (let DB calculate):');
        
        const minimalData = {
          discount_amount: discountAmount || 0,
          grr_amount: grrAmount || 0,
          pri_amount: priAmount || 0,
          updated_at: new Date().toISOString()
        };

        const { data: minData, error: minError } = await supabase
          .from('vendor_payment_schedule')
          .update(minimalData)
          .eq('id', testPaymentId)
          .select();

        if (minError) {
          console.log(`\n❌ MINIMAL UPDATE ALSO FAILED: ${minError.message}`);
          console.log('\n💡 The constraint might be a trigger or computed column');
          console.log('   We need to investigate the table definition more deeply');
        } else {
          console.log('\n✅✅✅ MINIMAL UPDATE SUCCEEDED! ✅✅✅');
          console.log(`   Final amount calculated by DB: ${minData[0].final_bill_amount}`);
          console.log('\n🎉 SOLUTION: Don\'t send final_bill_amount, let DB calculate it!');
        }
      } else {
        console.log('\n✅✅✅ ALTERNATIVE UPDATE SUCCEEDED! ✅✅✅');
        console.log(`   New final_bill_amount: ${altData[0].final_bill_amount}`);
      }
      
    } else {
      console.log('\n✅✅✅ UPDATE SUCCEEDED! ✅✅✅');
      console.log(`   New final_bill_amount: ${data[0].final_bill_amount}`);
      console.log(`   New grr_amount: ${data[0].grr_amount}`);
      console.log('\n🎉 THE FIX WORKS!');
    }

  } catch (error) {
    console.error('\n❌ UNEXPECTED ERROR:', error);
  }
}

testExactFrontendScenario()
  .then(() => {
    console.log('\n\n✅ Test complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n❌ Fatal error:', error);
    process.exit(1);
  });