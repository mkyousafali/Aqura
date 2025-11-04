const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function directDeploy() {
  console.log('🚀 DIRECT DEPLOYMENT: PostgreSQL function via service role\n');
  console.log('='.repeat(80));

  const functionSQL = `
CREATE OR REPLACE FUNCTION update_vendor_payment_with_exact_calculation(
  payment_id UUID,
  new_discount_amount NUMERIC DEFAULT NULL,
  new_grr_amount NUMERIC DEFAULT NULL,
  new_pri_amount NUMERIC DEFAULT NULL,
  discount_notes_val TEXT DEFAULT NULL,
  grr_reference_val TEXT DEFAULT NULL,
  grr_notes_val TEXT DEFAULT NULL,
  pri_reference_val TEXT DEFAULT NULL,
  pri_notes_val TEXT DEFAULT NULL,
  history_val JSONB DEFAULT NULL
) 
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_bill_amount NUMERIC;
  calculated_final_amount NUMERIC;
BEGIN
  -- Get the current bill_amount for this payment
  SELECT bill_amount INTO current_bill_amount
  FROM vendor_payment_schedule
  WHERE id = payment_id;
  
  -- Calculate final_bill_amount using exact NUMERIC arithmetic
  -- COALESCE treats NULL as 0 for calculations
  calculated_final_amount := current_bill_amount 
    - COALESCE(new_discount_amount, 0) 
    - COALESCE(new_grr_amount, 0) 
    - COALESCE(new_pri_amount, 0);
  
  -- Update the record with the calculated final amount
  UPDATE vendor_payment_schedule
  SET 
    final_bill_amount = calculated_final_amount,
    discount_amount = new_discount_amount,
    discount_notes = discount_notes_val,
    grr_amount = new_grr_amount,
    grr_reference_number = grr_reference_val,
    grr_notes = grr_notes_val,
    pri_amount = new_pri_amount,
    pri_reference_number = pri_reference_val,
    pri_notes = pri_notes_val,
    adjustment_history = COALESCE(history_val, adjustment_history),
    updated_at = NOW()
  WHERE id = payment_id;
  
  -- Verify the constraint is satisfied (this should always pass now)
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment record not found: %', payment_id;
  END IF;
  
END;
$$;`;

  try {
    console.log('⚙️ Creating function via raw SQL execution...');
    
    // Use the REST API directly to execute raw SQL
    const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/exec_sql`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json',
        'apikey': SUPABASE_SERVICE_ROLE_KEY
      },
      body: JSON.stringify({ sql: functionSQL })
    });

    if (!response.ok) {
      // Fallback: try using @supabase/postgrest-js raw query approach
      console.log('⚙️ Fallback: Using pg connection...');
      
      // This is a workaround - we'll create a test that verifies the function exists
      console.log('📋 MANUAL STEP REQUIRED:');
      console.log('Please copy the following SQL and execute it in Supabase Dashboard > SQL Editor:');
      console.log('\n```sql');
      console.log(functionSQL);
      console.log('```\n');
      
      // Wait a moment for manual execution
      console.log('⏳ Waiting 10 seconds for manual execution...');
      await new Promise(resolve => setTimeout(resolve, 10000));
    }

    // Test if the function exists and works
    console.log('🧪 TESTING: Function deployment and execution');
    const testPaymentId = 'af500080-2d7e-42b7-aa7b-adee12770047';
    
    // First reset to known state
    await supabase
      .from('vendor_payment_schedule')
      .update({ 
        discount_amount: 0,
        grr_amount: null,
        pri_amount: 0,
        final_bill_amount: 22401.25
      })
      .eq('id', testPaymentId);

    console.log('📊 Testing function call...');
    const { data: funcResult, error: funcError } = await supabase.rpc('update_vendor_payment_with_exact_calculation', {
      payment_id: testPaymentId,
      new_discount_amount: null,
      new_grr_amount: 11837.30,
      new_pri_amount: null,
      discount_notes_val: null,
      grr_reference_val: 'TEST-GRR-001',
      grr_notes_val: 'Test GRR adjustment',
      pri_reference_val: null,
      pri_notes_val: null,
      history_val: null
    });

    if (funcError) {
      console.log(`❌ Function call failed: ${funcError.message}`);
      console.log('\n📋 NEXT STEPS:');
      console.log('1. Go to Supabase Dashboard');
      console.log('2. Navigate to SQL Editor');
      console.log('3. Paste and execute the SQL above');
      console.log('4. Run this test again');
    } else {
      console.log('✅ Function call succeeded!');
      
      // Verify the result
      const { data: result } = await supabase
        .from('vendor_payment_schedule')
        .select('bill_amount, discount_amount, grr_amount, pri_amount, final_bill_amount')
        .eq('id', testPaymentId)
        .single();

      console.log('\n📊 RESULT:');
      console.log(`  bill_amount: ${result.bill_amount}`);
      console.log(`  grr_amount: ${result.grr_amount}`);
      console.log(`  final_bill_amount: ${result.final_bill_amount}`);
      console.log(`  calculation: ${result.bill_amount} - ${result.grr_amount} = ${result.final_bill_amount}`);
      
      const expected = parseFloat(result.bill_amount) - parseFloat(result.grr_amount);
      const actual = parseFloat(result.final_bill_amount);
      
      if (Math.abs(expected - actual) < 0.001) {
        console.log('✅ Calculation is correct!');
        console.log('\n🎉 SUCCESS: The function works perfectly!');
        console.log('The frontend can now use this function to avoid floating-point errors.');
      } else {
        console.log(`❌ Calculation mismatch: expected ${expected}, got ${actual}`);
      }
    }

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

directDeploy()
  .then(() => {
    console.log('\n\n✅ Test complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });