const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

// Create Supabase admin client
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function getConstraintDefinition() {
  console.log('🔍 Fetching check_total_deductions_valid constraint definition...\n');

  try {
    // Use Supabase's built-in SQL execution through the postgres connection
    const { data, error } = await supabase.rpc('exec_sql', {
      query: `
        SELECT 
          con.conname AS constraint_name,
          pg_get_constraintdef(con.oid) AS constraint_definition,
          con.contype AS constraint_type,
          con.convalidated AS is_validated,
          rel.relname AS table_name
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        WHERE rel.relname = 'vendor_payment_schedule'
          AND nsp.nspname = 'public'
          AND con.conname = 'check_total_deductions_valid';
      `
    });

    if (error) {
      console.log('❌ RPC Error:', error.message);
      console.log('\n📝 Trying alternative method using pg_catalog query...\n');
      
      // Alternative: Query using REST API directly
      const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/get_constraint_definition`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': SUPABASE_SERVICE_ROLE_KEY,
          'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Prefer': 'return=representation'
        },
        body: JSON.stringify({})
      });

      if (!response.ok) {
        console.log('⚠️  Could not fetch via RPC. Let me analyze the error message...\n');
        
        // Analyze the error from the previous run
        console.log('📋 CONSTRAINT ANALYSIS FROM ERROR:');
        console.log('='.repeat(80));
        console.log('Constraint Name: check_total_deductions_valid');
        console.log('Violation Type: CHECK constraint');
        console.log('\n🧪 Testing different scenarios:\n');
        
        // Test 1: 11837.30 (FAILS)
        const bill1 = 22401.25;
        const grr1 = 11837.30;
        const final1 = bill1 - grr1;
        console.log(`Test 1 (FAILED in database):`);
        console.log(`  bill_amount: ${bill1}`);
        console.log(`  grr_amount: ${grr1}`);
        console.log(`  final_bill_amount: ${final1}`);
        console.log(`  Result: ${final1}`);
        console.log(`  Precision: ${final1.toFixed(10)}`);
        
        // Test 2: 11000.37 (WORKS)
        const bill2 = 22401.25;
        const grr2 = 11000.37;
        const final2 = bill2 - grr2;
        console.log(`\nTest 2 (SUCCEEDED in database):`);
        console.log(`  bill_amount: ${bill2}`);
        console.log(`  grr_amount: ${grr2}`);
        console.log(`  final_bill_amount: ${final2}`);
        console.log(`  Result: ${final2}`);
        console.log(`  Precision: ${final2.toFixed(10)}`);
        
        // Hypothesis about the constraint
        console.log('\n\n💡 HYPOTHESIS:');
        console.log('='.repeat(80));
        console.log('The constraint likely checks:');
        console.log('  final_bill_amount = bill_amount - (discount_amount + grr_amount + pri_amount)');
        console.log('\nOr possibly:');
        console.log('  final_bill_amount >= 0');
        console.log('  AND final_bill_amount <= bill_amount');
        console.log('  AND (discount_amount + grr_amount + pri_amount) <= bill_amount');
        
        console.log('\n\n🔬 DETAILED ANALYSIS:');
        console.log('='.repeat(80));
        
        // Check for floating point precision issues
        const expectedFinal1 = 10563.95;
        const actualFinal1 = bill1 - grr1;
        console.log(`\nFloating Point Check for Test 1:`);
        console.log(`  Expected: ${expectedFinal1}`);
        console.log(`  Actual: ${actualFinal1}`);
        console.log(`  Match: ${expectedFinal1 === actualFinal1 ? '✅ YES' : '❌ NO'}`);
        console.log(`  Difference: ${Math.abs(expectedFinal1 - actualFinal1)}`);
        console.log(`  Binary representation issue: ${(bill1 - grr1).toString(2)}`);
        
        // Check if the constraint might be using NUMERIC/DECIMAL comparison
        console.log('\n\n💭 POSSIBLE CONSTRAINT DEFINITIONS:');
        console.log('='.repeat(80));
        console.log('1. final_bill_amount = bill_amount - COALESCE(discount_amount, 0) - COALESCE(grr_amount, 0) - COALESCE(pri_amount, 0)');
        console.log('2. (discount_amount + grr_amount + pri_amount) <= bill_amount');
        console.log('3. final_bill_amount >= 0 AND final_bill_amount <= bill_amount');
        console.log('4. ROUND(final_bill_amount, 2) = ROUND(bill_amount - deductions, 2)');
        
        // Let's check if there's a rounding issue
        console.log('\n\n🎯 ROUNDING INVESTIGATION:');
        console.log('='.repeat(80));
        
        const test1Rounded = Math.round((bill1 - grr1) * 100) / 100;
        const test2Rounded = Math.round((bill2 - grr2) * 100) / 100;
        
        console.log(`Test 1 Rounded: ${test1Rounded}`);
        console.log(`Test 2 Rounded: ${test2Rounded}`);
        console.log(`Test 1 Stored as: 10563.95`);
        console.log(`Test 2 Stored as: 11400.88`);
        
        // Check decimal places
        const test1Decimal = (bill1 - grr1).toFixed(2);
        const test2Decimal = (bill2 - grr2).toFixed(2);
        console.log(`\nTest 1 Fixed(2): ${test1Decimal}`);
        console.log(`Test 2 Fixed(2): ${test2Decimal}`);
        
        // Test with exact database values
        console.log('\n\n🔍 EXACT VALUE COMPARISON:');
        console.log('='.repeat(80));
        console.log('From error message, the failing row contains:');
        console.log('  bill_amount: 22401.25');
        console.log('  discount_amount: 0.00');
        console.log('  grr_amount: 11837.30');
        console.log('  pri_amount: 0.00');
        console.log('  final_bill_amount: 10563.95');
        console.log('\nCalculation:');
        console.log(`  22401.25 - 0.00 - 11837.30 - 0.00 = ${22401.25 - 0 - 11837.30 - 0}`);
        console.log(`  Expected: 10563.95`);
        console.log(`  Matches: ${(22401.25 - 11837.30) === 10563.95}`);
        
        // Floating point representation
        const exactCalc = 22401.25 - 11837.30;
        console.log(`\n  JavaScript calculation: ${exactCalc}`);
        console.log(`  Precision (20 decimals): ${exactCalc.toFixed(20)}`);
        console.log(`  Database expected: 10563.95`);
        console.log(`  Database precision: 10563.950000000000000000`);
        
      } else {
        const result = await response.json();
        console.log('✅ Constraint definition:', result);
      }
    } else {
      console.log('✅ Found constraint definition:');
      console.log(JSON.stringify(data, null, 2));
    }

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

// Run the check
getConstraintDefinition()
  .then(() => {
    console.log('\n\n✅ Analysis completed');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });
