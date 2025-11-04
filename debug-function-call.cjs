const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function debugFunctionCall() {
  console.log('🐛 DEBUGGING: Function call with exact frontend parameters\n');
  console.log('='.repeat(80));

  const testPaymentId = 'af500080-2d7e-42b7-aa7b-adee12770047';

  try {
    // First, let's check if the function exists
    console.log('1. Checking if function exists...');
    const { data: functions, error: listError } = await supabase.rpc('sql', {
      query: "SELECT proname FROM pg_proc WHERE proname = 'update_vendor_payment_with_exact_calculation'"
    });

    if (listError) {
      console.log('❌ Could not check function existence:', listError.message);
    } else {
      console.log('✅ Function exists in database');
    }

    // Reset record to clean state
    console.log('\n2. Resetting record to clean state...');
    await supabase
      .from('vendor_payment_schedule')
      .update({ 
        discount_amount: null,
        grr_amount: null,
        pri_amount: null,
        final_bill_amount: 22401.25 // Reset to bill_amount
      })
      .eq('id', testPaymentId);

    // Get current state
    const { data: current } = await supabase
      .from('vendor_payment_schedule')
      .select('bill_amount, original_final_amount, final_bill_amount, discount_amount, grr_amount, pri_amount')
      .eq('id', testPaymentId)
      .single();

    console.log('Current state:');
    console.log(`  bill_amount: ${current.bill_amount}`);
    console.log(`  original_final_amount: ${current.original_final_amount}`);
    console.log(`  final_bill_amount: ${current.final_bill_amount}`);

    // Test the exact call that frontend is making
    console.log('\n3. Testing exact frontend call...');
    const frontendParams = {
      payment_id: testPaymentId,
      new_discount_amount: null,
      new_grr_amount: 11837.30,
      new_pri_amount: null,
      discount_notes_val: null,
      grr_reference_val: '1234',
      grr_notes_val: null,
      pri_reference_val: null,
      pri_notes_val: null,
      history_val: null
    };

    console.log('Parameters:', JSON.stringify(frontendParams, null, 2));

    const { data: result, error: funcError } = await supabase.rpc('update_vendor_payment_with_exact_calculation', frontendParams);

    if (funcError) {
      console.log(`❌ Function call failed: ${funcError.message}`);
      console.log('Error details:', JSON.stringify(funcError, null, 2));
      
      // Let's try a simpler version
      console.log('\n4. Testing simplified call...');
      const simpleParams = {
        payment_id: testPaymentId,
        new_grr_amount: 11837.30,
        grr_reference_val: '1234'
      };

      const { data: simpleResult, error: simpleError } = await supabase.rpc('update_vendor_payment_with_exact_calculation', simpleParams);
      
      if (simpleError) {
        console.log(`❌ Simplified call also failed: ${simpleError.message}`);
        
        // Let's check what the constraint error is exactly
        console.log('\n5. Testing constraint validation manually...');
        const reference_amount = current.original_final_amount || current.bill_amount;
        const total_deductions = 11837.30;
        
        console.log(`Reference amount: ${reference_amount}`);
        console.log(`Total deductions: ${total_deductions}`);
        console.log(`Constraint check: ${total_deductions} <= ${reference_amount} = ${total_deductions <= reference_amount}`);
        
        if (total_deductions > reference_amount) {
          console.log('\n❌ BUSINESS LOGIC ISSUE:');
          console.log(`Cannot deduct ${total_deductions} from ${reference_amount}`);
          console.log('This is not a technical error, but a business rule violation');
          console.log('\n💡 SOLUTIONS:');
          console.log('1. Reduce the GRR amount to fit within available amount');
          console.log('2. Check if the original bill amount is correct');
          console.log('3. Verify if there are existing deductions');
        } else {
          console.log('✅ Constraint should pass - there might be another issue');
        }
      } else {
        console.log('✅ Simplified call succeeded!');
      }
    } else {
      console.log('✅ Function call succeeded!');
      
      // Check the result
      const { data: updated } = await supabase
        .from('vendor_payment_schedule')
        .select('bill_amount, final_bill_amount, grr_amount, grr_reference_number')
        .eq('id', testPaymentId)
        .single();

      console.log('\nUpdated values:');
      console.log(`  bill_amount: ${updated.bill_amount}`);
      console.log(`  grr_amount: ${updated.grr_amount}`);
      console.log(`  final_bill_amount: ${updated.final_bill_amount}`);
      console.log(`  grr_reference_number: ${updated.grr_reference_number}`);
    }

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

debugFunctionCall()
  .then(() => {
    console.log('\n✅ Debug complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });