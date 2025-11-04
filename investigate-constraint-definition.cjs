const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function investigateConstraintDefinition() {
  console.log('🔍 DEEP INVESTIGATION: Constraint Definition\n');
  console.log('='.repeat(80));

  try {
    // Let's try to get the exact constraint definition using a custom function
    console.log('⚙️ Creating a function to get constraint definition...');
    
    const getConstraintSQL = `
    CREATE OR REPLACE FUNCTION get_constraint_definition(table_name_param TEXT, constraint_name_param TEXT)
    RETURNS TEXT
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
        constraint_def TEXT;
    BEGIN
        SELECT pg_get_constraintdef(c.oid)
        INTO constraint_def
        FROM pg_constraint c
        JOIN pg_class t ON c.conrelid = t.oid
        JOIN pg_namespace n ON t.relnamespace = n.oid
        WHERE t.relname = table_name_param
        AND c.conname = constraint_name_param
        AND n.nspname = 'public';
        
        RETURN constraint_def;
    END;
    $$;`;

    // First deploy the helper function
    const { error: deployError } = await supabase.rpc('sql', { query: getConstraintSQL });
    
    // Now get the constraint definition
    const { data: constraintDef, error: constraintError } = await supabase.rpc('get_constraint_definition', {
      table_name_param: 'vendor_payment_schedule',
      constraint_name_param: 'check_total_deductions_valid'
    });

    if (constraintError) {
      console.log(`❌ Could not get constraint definition: ${constraintError.message}`);
      
      // Alternative approach: let's test what the constraint is actually checking
      console.log('\n🧪 TESTING: What values does the constraint accept?');
      
      const testPaymentId = 'af500080-2d7e-42b7-aa7b-adee12770047';
      
      // Reset to known state
      await supabase
        .from('vendor_payment_schedule')
        .update({ 
          discount_amount: null,
          grr_amount: null,
          pri_amount: null,
          final_bill_amount: 22401.25
        })
        .eq('id', testPaymentId);

      // Test 1: Can we update just final_bill_amount to the calculated value?
      console.log('\nTest A: Update only final_bill_amount to 10563.95');
      const { error: testA } = await supabase
        .from('vendor_payment_schedule')
        .update({ final_bill_amount: 10563.95 })
        .eq('id', testPaymentId);
      
      if (testA) {
        console.log(`❌ Failed: ${testA.message}`);
      } else {
        console.log('✅ Succeeded - final_bill_amount can be updated independently');
      }

      // Test 2: What if we set grr_amount to 11837.30 but DON'T update final_bill_amount?
      console.log('\nTest B: Update only grr_amount to 11837.30 (keep final_bill_amount as 22401.25)');
      const { error: testB } = await supabase
        .from('vendor_payment_schedule')
        .update({ grr_amount: 11837.30 })
        .eq('id', testPaymentId);
      
      if (testB) {
        console.log(`❌ Failed: ${testB.message}`);
        console.log('This confirms the constraint validates the calculation');
      } else {
        console.log('✅ Succeeded - constraint does NOT validate calculation?');
      }

      // Test 3: Update both together with exact values
      console.log('\nTest C: Update both grr_amount=11837.30 AND final_bill_amount=10563.95');
      const { error: testC } = await supabase
        .from('vendor_payment_schedule')
        .update({ 
          grr_amount: 11837.30,
          final_bill_amount: 10563.95
        })
        .eq('id', testPaymentId);
      
      if (testC) {
        console.log(`❌ Failed: ${testC.message}`);
        console.log('Even exact values fail - there might be precision issues in the constraint itself');
      } else {
        console.log('✅ Succeeded - exact values work');
      }

      // Test 4: Try with string-based NUMERIC values
      console.log('\nTest D: Using PostgreSQL NUMERIC calculation directly');
      const { error: testD } = await supabase
        .from('vendor_payment_schedule')
        .update({ 
          grr_amount: 11837.30,
          final_bill_amount: supabase.sql`22401.25 - 11837.30`
        })
        .eq('id', testPaymentId);
      
      if (testD) {
        console.log(`❌ Failed: ${testD.message}`);
      } else {
        console.log('✅ Succeeded - PostgreSQL calculation works');
      }

      // Test 5: Let's see what the actual values are after our function
      console.log('\n🔍 DEBUGGING: Check what our function actually produces');
      
      // Reset and call our function
      await supabase
        .from('vendor_payment_schedule')
        .update({ 
          discount_amount: null,
          grr_amount: null,
          pri_amount: null,
          final_bill_amount: 22401.25
        })
        .eq('id', testPaymentId);

      // Call our function and see what it produces
      console.log('Calling our function...');
      const { error: funcError } = await supabase.rpc('update_vendor_payment_with_exact_calculation', {
        payment_id: testPaymentId,
        new_discount_amount: null,
        new_grr_amount: 11837.30,
        new_pri_amount: null
      });

      if (funcError) {
        console.log(`Function failed: ${funcError.message}`);
        
        // Let's check if our function calculation is correct by testing it separately
        console.log('\n🧮 TESTING: Our function calculation logic separately');
        const { data: calcResult, error: calcError } = await supabase.rpc('sql', {
          query: `SELECT 22401.25 - COALESCE(NULL, 0) - COALESCE(11837.30, 0) - COALESCE(NULL, 0) AS calculated_result`
        });
        
        if (!calcError) {
          console.log(`PostgreSQL calculation result: ${calcResult}`);
        }
      }

    } else {
      console.log('✅ Got constraint definition:');
      console.log(`Constraint: ${constraintDef}`);
      
      // Parse the constraint to understand what it's checking
      console.log('\n📝 CONSTRAINT ANALYSIS:');
      if (constraintDef.includes('final_bill_amount')) {
        console.log('✓ Constraint involves final_bill_amount');
      }
      if (constraintDef.includes('bill_amount')) {
        console.log('✓ Constraint involves bill_amount');
      }
      if (constraintDef.includes('discount_amount')) {
        console.log('✓ Constraint involves discount_amount');
      }
      if (constraintDef.includes('grr_amount')) {
        console.log('✓ Constraint involves grr_amount');
      }
      if (constraintDef.includes('pri_amount')) {
        console.log('✓ Constraint involves pri_amount');
      }
    }

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

investigateConstraintDefinition()
  .then(() => {
    console.log('\n\n✅ Investigation complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });