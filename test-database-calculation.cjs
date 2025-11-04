const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function testDatabaseCalculation() {
  console.log('🧪 TESTING: Does database auto-calculate final_bill_amount?\n');
  console.log('='.repeat(80));

  const testPaymentId = 'af500080-2d7e-42b7-aa7b-adee12770047';

  try {
    // Reset to known state
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

    // Test: Update only deduction amounts (not final_bill_amount)
    console.log('\n🧪 TEST: Update only grr_amount (not final_bill_amount)');
    const { error } = await supabase
      .from('vendor_payment_schedule')
      .update({ 
        grr_amount: 11837.30
        // Note: NOT updating final_bill_amount
      })
      .eq('id', testPaymentId);

    if (error) {
      console.log(`❌ UPDATE FAILED: ${error.message}`);
      console.log('\nThis means the database does NOT auto-calculate final_bill_amount');
      console.log('The constraint requires us to provide the correct final_bill_amount');
    } else {
      console.log('✅ UPDATE SUCCEEDED');
      
      // Get new state
      const { data: after } = await supabase
        .from('vendor_payment_schedule')
        .select('bill_amount, discount_amount, grr_amount, pri_amount, final_bill_amount')
        .eq('id', testPaymentId)
        .single();

      console.log('\n📊 AFTER UPDATE:');
      console.log(`  bill_amount: ${after.bill_amount}`);
      console.log(`  discount_amount: ${after.discount_amount}`);
      console.log(`  grr_amount: ${after.grr_amount}`);
      console.log(`  pri_amount: ${after.pri_amount}`);
      console.log(`  final_bill_amount: ${after.final_bill_amount}`);

      if (after.final_bill_amount === before.final_bill_amount) {
        console.log('\n🤔 final_bill_amount did NOT change automatically');
        console.log('Database does not have an auto-calculation trigger');
      } else {
        console.log('\n✨ final_bill_amount was automatically updated!');
        console.log('Database has a trigger that calculates final_bill_amount');
      }
    }

    console.log('\n\n💡 SOLUTION APPROACH:');
    console.log('='.repeat(80));
    if (error) {
      console.log('Since the constraint requires exact final_bill_amount:');
      console.log('1. We must calculate it on the frontend');
      console.log('2. But use PostgreSQL NUMERIC-compatible approach');
      console.log('3. Send the calculation as a raw SQL operation');
    } else {
      console.log('Since database auto-calculates final_bill_amount:');
      console.log('1. We can update only the deduction amounts');
      console.log('2. Database will handle the calculation exactly');
    }

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

testDatabaseCalculation()
  .then(() => {
    console.log('\n\n✅ Test complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });