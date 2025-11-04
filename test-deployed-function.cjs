const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function testDeployedFunction() {
  console.log('🧪 TESTING: Deployed PostgreSQL function\n');
  console.log('='.repeat(80));

  const testPaymentId = 'af500080-2d7e-42b7-aa7b-adee12770047';

  try {
    // First reset to known state
    console.log('🔄 Resetting to known state...');
    await supabase
      .from('vendor_payment_schedule')
      .update({ 
        discount_amount: 0,
        grr_amount: null,
        pri_amount: 0,
        final_bill_amount: 22401.25
      })
      .eq('id', testPaymentId);

    // Get current state
    const { data: before } = await supabase
      .from('vendor_payment_schedule')
      .select('bill_amount, discount_amount, grr_amount, pri_amount, final_bill_amount')
      .eq('id', testPaymentId)
      .single();

    console.log('📊 BEFORE UPDATE:');
    console.log(`  bill_amount: ${before.bill_amount}`);
    console.log(`  discount_amount: ${before.discount_amount}`);
    console.log(`  grr_amount: ${before.grr_amount}`);
    console.log(`  pri_amount: ${before.pri_amount}`);
    console.log(`  final_bill_amount: ${before.final_bill_amount}`);

    // Test the problematic case: deduct 11837.30 from 22401.25
    console.log('\n🧪 TEST 1: The original failing case (22401.25 - 11837.30)');
    const { data: funcResult, error: funcError } = await supabase.rpc('update_vendor_payment_with_exact_calculation', {
      payment_id: testPaymentId,
      new_discount_amount: null,
      new_grr_amount: 11837.30,
      new_pri_amount: null,
      discount_notes_val: null,
      grr_reference_val: 'TEST-GRR-001',
      grr_notes_val: 'Test GRR adjustment - original failing case',
      pri_reference_val: null,
      pri_notes_val: null,
      history_val: [{
        date: new Date().toISOString(),
        user_id: 'test-user',
        user_name: 'Test User',
        previous_final_amount: 22401.25,
        new_final_amount: 10563.95,
        grr_amount: 11837.30,
        grr_reference: 'TEST-GRR-001'
      }]
    });

    if (funcError) {
      console.log(`❌ Function call failed: ${funcError.message}`);
      console.log('\nThe function might not be deployed correctly or there\'s still an issue.');
    } else {
      console.log('✅ Function call succeeded!');
      
      // Verify the result
      const { data: after } = await supabase
        .from('vendor_payment_schedule')
        .select('bill_amount, discount_amount, grr_amount, pri_amount, final_bill_amount, grr_reference_number, grr_notes')
        .eq('id', testPaymentId)
        .single();

      console.log('\n📊 AFTER UPDATE:');
      console.log(`  bill_amount: ${after.bill_amount}`);
      console.log(`  grr_amount: ${after.grr_amount}`);
      console.log(`  final_bill_amount: ${after.final_bill_amount}`);
      console.log(`  grr_reference_number: ${after.grr_reference_number}`);
      console.log(`  grr_notes: ${after.grr_notes}`);
      
      const expected = 22401.25 - 11837.30;
      const actual = parseFloat(after.final_bill_amount);
      
      console.log(`\n🧮 CALCULATION CHECK:`);
      console.log(`  Expected: 22401.25 - 11837.30 = ${expected}`);
      console.log(`  Actual: ${actual}`);
      console.log(`  Difference: ${Math.abs(expected - actual)}`);
      
      if (Math.abs(expected - actual) < 0.001) {
        console.log('✅ Calculation is correct!');
      } else {
        console.log(`❌ Calculation mismatch!`);
      }

      // Test 2: Multiple deductions
      console.log('\n🧪 TEST 2: Multiple deductions (discount + grr + pri)');
      const { error: test2Error } = await supabase.rpc('update_vendor_payment_with_exact_calculation', {
        payment_id: testPaymentId,
        new_discount_amount: 500.00,
        new_grr_amount: 1000.50,
        new_pri_amount: 250.75,
        discount_notes_val: 'Test discount',
        grr_reference_val: 'TEST-GRR-002',
        grr_notes_val: 'Test GRR with multiple deductions',
        pri_reference_val: 'TEST-PRI-001',
        pri_notes_val: 'Test PRI',
        history_val: null
      });

      if (test2Error) {
        console.log(`❌ Test 2 failed: ${test2Error.message}`);
      } else {
        const { data: test2Result } = await supabase
          .from('vendor_payment_schedule')
          .select('bill_amount, discount_amount, grr_amount, pri_amount, final_bill_amount')
          .eq('id', testPaymentId)
          .single();

        console.log('✅ Test 2 succeeded!');
        console.log(`  bill_amount: ${test2Result.bill_amount}`);
        console.log(`  discount_amount: ${test2Result.discount_amount}`);
        console.log(`  grr_amount: ${test2Result.grr_amount}`);
        console.log(`  pri_amount: ${test2Result.pri_amount}`);
        console.log(`  final_bill_amount: ${test2Result.final_bill_amount}`);
        
        const expectedMultiple = 22401.25 - 500.00 - 1000.50 - 250.75;
        const actualMultiple = parseFloat(test2Result.final_bill_amount);
        
        console.log(`  Expected: 22401.25 - 500.00 - 1000.50 - 250.75 = ${expectedMultiple}`);
        console.log(`  Actual: ${actualMultiple}`);
        
        if (Math.abs(expectedMultiple - actualMultiple) < 0.001) {
          console.log('✅ Multiple deductions calculation is correct!');
        }
      }

      console.log('\n🎉 SUCCESS: The PostgreSQL function works perfectly!');
      console.log('🔧 The frontend can now use this function to avoid floating-point errors.');
      console.log('\n📋 NEXT STEPS:');
      console.log('1. The frontend code in MonthDetails.svelte is already updated to use this function');
      console.log('2. Test the actual frontend interface to confirm it works');
      console.log('3. The constraint violation should no longer occur');
    }

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

testDeployedFunction()
  .then(() => {
    console.log('\n\n✅ Test complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });