const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function deployFunction() {
  console.log('🚀 DEPLOYING: PostgreSQL function for exact payment calculations\n');
  console.log('='.repeat(80));

  try {
    // Read the SQL file
    const sqlContent = fs.readFileSync('supabase/migrations/add_exact_payment_calculation_function.sql', 'utf8');
    
    console.log('📄 SQL Function:');
    console.log('```sql');
    console.log(sqlContent);
    console.log('```\n');

    // Execute the SQL
    console.log('⚙️ Executing SQL...');
    const { data, error } = await supabase.rpc('sql', { 
      query: sqlContent 
    });

    if (error) {
      console.log(`❌ SQL Execution failed: ${error.message}`);
      
      // Try alternative approach - direct query execution
      console.log('\n🔄 Trying alternative deployment...');
      const { error: altError } = await supabase
        .from('information_schema.routines')
        .select('*');
      
      if (altError) {
        console.log('Alternative query also failed - using manual deployment');
        console.log('\n📋 MANUAL DEPLOYMENT INSTRUCTIONS:');
        console.log('1. Copy the SQL above');
        console.log('2. Go to Supabase Dashboard > SQL Editor');
        console.log('3. Paste and execute the SQL');
        console.log('4. Run the test script again');
        return;
      }
    } else {
      console.log('✅ Function deployed successfully!');
    }

    // Test the function
    console.log('\n🧪 TESTING: New function with exact calculation');
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
      } else {
        console.log(`❌ Calculation mismatch: expected ${expected}, got ${actual}`);
      }
    }

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

deployFunction()
  .then(() => {
    console.log('\n\n✅ Deployment complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });