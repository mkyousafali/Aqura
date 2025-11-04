const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function investigateConstraint() {
  console.log('🔬 DEEP DIVE: Investigating the check_total_deductions_valid constraint\n');
  console.log('='.repeat(80));

  try {
    // Get the table schema
    const { data: columns, error: columnsError } = await supabase
      .from('information_schema.columns')
      .select('*')
      .eq('table_name', 'vendor_payment_schedule')
      .eq('table_schema', 'public');

    if (columnsError) {
      console.log('❌ Error fetching columns:', columnsError.message);
    } else {
      console.log('📋 TABLE COLUMNS:');
      const relevantColumns = columns.filter(col => 
        ['bill_amount', 'final_bill_amount', 'discount_amount', 'grr_amount', 'pri_amount'].includes(col.column_name)
      );
      
      relevantColumns.forEach(col => {
        console.log(`  ${col.column_name}: ${col.data_type} (nullable: ${col.is_nullable})`);
      });
    }

    // Let's try to get constraint info another way
    console.log('\n\n🔍 ANALYZING FAILING RECORD:');
    console.log('='.repeat(80));
    
    const testPaymentId = 'af500080-2d7e-42b7-aa7b-adee12770047';
    const { data: payment } = await supabase
      .from('vendor_payment_schedule')
      .select('*')
      .eq('id', testPaymentId)
      .single();

    console.log('Current values:');
    console.log(`  bill_amount: ${payment.bill_amount}`);
    console.log(`  discount_amount: ${payment.discount_amount}`);
    console.log(`  grr_amount: ${payment.grr_amount}`);
    console.log(`  pri_amount: ${payment.pri_amount}`);
    console.log(`  final_bill_amount: ${payment.final_bill_amount}`);

    // Test individual column updates
    console.log('\n\n🧪 TESTING INDIVIDUAL COLUMN UPDATES:');
    console.log('='.repeat(80));

    // Test 1: Just update grr_amount
    console.log('\nTest 1: Update only grr_amount to 11837.30');
    const { error: test1Error } = await supabase
      .from('vendor_payment_schedule')
      .update({ grr_amount: 11837.30 })
      .eq('id', testPaymentId);

    if (test1Error) {
      console.log(`❌ FAILED: ${test1Error.message}`);
    } else {
      console.log('✅ SUCCESS: grr_amount updated');
      
      // Get updated values
      const { data: updated } = await supabase
        .from('vendor_payment_schedule')
        .select('grr_amount, final_bill_amount')
        .eq('id', testPaymentId)
        .single();
      
      console.log(`  New grr_amount: ${updated.grr_amount}`);
      console.log(`  New final_bill_amount: ${updated.final_bill_amount}`);
    }

    // Test 2: Update final_bill_amount only
    console.log('\nTest 2: Update only final_bill_amount to 10563.95');
    const { error: test2Error } = await supabase
      .from('vendor_payment_schedule')
      .update({ final_bill_amount: 10563.95 })
      .eq('id', testPaymentId);

    if (test2Error) {
      console.log(`❌ FAILED: ${test2Error.message}`);
    } else {
      console.log('✅ SUCCESS: final_bill_amount updated');
    }

    // Test 3: Check if there's a trigger
    console.log('\n\n🔍 CHECKING FOR TRIGGERS:');
    console.log('='.repeat(80));
    
    const { data: triggers, error: triggersError } = await supabase
      .from('information_schema.triggers')
      .select('*')
      .eq('event_object_table', 'vendor_payment_schedule');

    if (triggersError) {
      console.log('❌ Error fetching triggers:', triggersError.message);
    } else {
      console.log(`Found ${triggers?.length || 0} triggers:`);
      triggers?.forEach(trigger => {
        console.log(`  - ${trigger.trigger_name} (${trigger.action_timing} ${trigger.event_manipulation})`);
      });
    }

    // Test 4: Let's see what happens with NULL values
    console.log('\n\n🧪 TESTING NULL HANDLING:');
    console.log('='.repeat(80));

    // Reset to known good state first
    await supabase
      .from('vendor_payment_schedule')
      .update({ 
        grr_amount: 0,
        final_bill_amount: 22401.25
      })
      .eq('id', testPaymentId);

    // Test with explicit 0 vs null
    console.log('\nTest 4a: Update with explicit 0 values');
    const { error: test4aError } = await supabase
      .from('vendor_payment_schedule')
      .update({ 
        discount_amount: 0,
        grr_amount: 11837.30,
        pri_amount: 0,
        final_bill_amount: 10563.95
      })
      .eq('id', testPaymentId);

    if (test4aError) {
      console.log(`❌ FAILED: ${test4aError.message}`);
    } else {
      console.log('✅ SUCCESS with explicit 0s');
    }

    // Test with null values
    console.log('\nTest 4b: Update with null values');
    const { error: test4bError } = await supabase
      .from('vendor_payment_schedule')
      .update({ 
        discount_amount: null,
        grr_amount: 11837.30,
        pri_amount: null,
        final_bill_amount: 10563.95
      })
      .eq('id', testPaymentId);

    if (test4bError) {
      console.log(`❌ FAILED: ${test4bError.message}`);
    } else {
      console.log('✅ SUCCESS with nulls');
    }

    // Hypothesis: Maybe the constraint is on a computed column or uses COALESCE
    console.log('\n\n💡 HYPOTHESIS TEST:');
    console.log('='.repeat(80));
    console.log('The constraint might be:');
    console.log('CHECK (final_bill_amount = bill_amount - COALESCE(discount_amount, 0) - COALESCE(grr_amount, 0) - COALESCE(pri_amount, 0))');
    
    // Let's test with exact COALESCE logic
    const billAmount = 22401.25;
    const discountAmount = 0;
    const grrAmount = 11837.30;
    const priAmount = 0;
    
    // Calculate using COALESCE logic (treating null as 0)
    const calculatedFinal = billAmount - (discountAmount || 0) - (grrAmount || 0) - (priAmount || 0);
    
    console.log(`\nCalculation: ${billAmount} - ${discountAmount || 0} - ${grrAmount || 0} - ${priAmount || 0} = ${calculatedFinal}`);
    console.log(`JavaScript result: ${calculatedFinal}`);
    console.log(`JavaScript precision: ${calculatedFinal.toFixed(20)}`);

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

investigateConstraint()
  .then(() => {
    console.log('\n\n✅ Investigation complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });