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

async function checkVendorPaymentConstraints() {
  console.log('🔍 Checking vendor_payment_schedule table constraints...\n');

  try {
    // Query 1: Get all CHECK constraints on the table
    console.log('📋 CHECK CONSTRAINTS:');
    console.log('='.repeat(80));
    
    const { data: constraints, error: constraintsError } = await supabase
      .rpc('exec_sql', {
        sql: `
          SELECT 
            con.conname AS constraint_name,
            pg_get_constraintdef(con.oid) AS constraint_definition,
            con.contype AS constraint_type,
            con.convalidated AS is_validated
          FROM pg_constraint con
          JOIN pg_class rel ON rel.oid = con.conrelid
          JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
          WHERE rel.relname = 'vendor_payment_schedule'
            AND nsp.nspname = 'public'
            AND con.contype = 'c'
          ORDER BY con.conname;
        `
      });

    if (constraintsError) {
      // Try alternative method using information_schema
      console.log('⚠️  RPC method not available, trying direct query...\n');
      
      const { data: tableInfo, error: tableError } = await supabase
        .from('information_schema.check_constraints')
        .select('*');
      
      if (tableError) {
        console.log('❌ Error querying constraints:', tableError.message);
        console.log('\n📝 Trying raw SQL query via postgrest...\n');
        
        // Last resort: Use postgREST to query pg_catalog
        const response = await fetch(
          `${SUPABASE_URL}/rest/v1/rpc/exec_sql`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'apikey': SUPABASE_SERVICE_ROLE_KEY,
              'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
            },
            body: JSON.stringify({
              query: `
                SELECT 
                  con.conname AS constraint_name,
                  pg_get_constraintdef(con.oid) AS constraint_definition
                FROM pg_constraint con
                JOIN pg_class rel ON rel.oid = con.conrelid
                JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
                WHERE rel.relname = 'vendor_payment_schedule'
                  AND nsp.nspname = 'public'
                  AND con.contype = 'c';
              `
            })
          }
        );
      }
    } else {
      console.log('✅ Found constraints:', constraints);
    }

    // Query 2: Get table columns and their types
    console.log('\n📊 TABLE COLUMNS:');
    console.log('='.repeat(80));
    
    const { data: columns, error: columnsError } = await supabase
      .from('vendor_payment_schedule')
      .select('*')
      .limit(1);

    if (columnsError) {
      console.log('❌ Error querying columns:', columnsError.message);
    } else if (columns && columns.length > 0) {
      const sampleRow = columns[0];
      console.log('\n📝 Sample row structure:');
      Object.keys(sampleRow).forEach(key => {
        const value = sampleRow[key];
        const type = typeof value;
        console.log(`  - ${key}: ${type} = ${value}`);
      });
    }

    // Query 3: Check specific payment with the problematic values
    console.log('\n\n🔬 TESTING PROBLEMATIC CALCULATION:');
    console.log('='.repeat(80));
    
    const testPaymentId = 'af500080-2d7e-42b7-aa7b-adee12770047';
    
    const { data: payment, error: paymentError } = await supabase
      .from('vendor_payment_schedule')
      .select('*')
      .eq('id', testPaymentId)
      .single();

    if (paymentError) {
      console.log('❌ Error fetching payment:', paymentError.message);
    } else {
      console.log('\n💳 Current Payment Data:');
      console.log(`  ID: ${payment.id}`);
      console.log(`  Bill Number: ${payment.bill_number}`);
      console.log(`  Bill Amount: ${payment.bill_amount}`);
      console.log(`  Original Bill Amount: ${payment.original_bill_amount}`);
      console.log(`  Original Final Amount: ${payment.original_final_amount}`);
      console.log(`  Final Bill Amount: ${payment.final_bill_amount}`);
      console.log(`  Discount Amount: ${payment.discount_amount}`);
      console.log(`  GRR Amount: ${payment.grr_amount}`);
      console.log(`  PRI Amount: ${payment.pri_amount}`);
      
      // Calculate what the final amount should be
      const billAmount = parseFloat(payment.bill_amount || 0);
      const discountAmount = parseFloat(payment.discount_amount || 0);
      const grrAmount = parseFloat(payment.grr_amount || 0);
      const priAmount = parseFloat(payment.pri_amount || 0);
      const currentFinal = parseFloat(payment.final_bill_amount || 0);
      
      const calculatedFinal = billAmount - discountAmount - grrAmount - priAmount;
      const totalDeductions = discountAmount + grrAmount + priAmount;
      
      console.log('\n🧮 Calculations:');
      console.log(`  Formula: bill_amount - (discount + grr + pri)`);
      console.log(`  Formula: ${billAmount} - (${discountAmount} + ${grrAmount} + ${priAmount})`);
      console.log(`  Total Deductions: ${totalDeductions}`);
      console.log(`  Calculated Final: ${calculatedFinal}`);
      console.log(`  Current Final: ${currentFinal}`);
      console.log(`  Difference: ${Math.abs(calculatedFinal - currentFinal)}`);
      
      console.log('\n🧪 Testing: Can we subtract 11837.30 from 22401.25?');
      const testBase = 22401.25;
      const testDeduction = 11837.30;
      const testResult = testBase - testDeduction;
      console.log(`  ${testBase} - ${testDeduction} = ${testResult}`);
      console.log(`  Would this pass constraint? ${testResult >= 0 ? '✅ YES' : '❌ NO'}`);
      
      // Test updating with the problematic values
      console.log('\n\n🧪 ATTEMPTING TEST UPDATE (11837.30 GRR):');
      console.log('='.repeat(80));
      
      const { data: updateTest1, error: updateError1 } = await supabase
        .from('vendor_payment_schedule')
        .update({
          grr_amount: 11837.30,
          final_bill_amount: 22401.25 - 11837.30 // 10563.95
        })
        .eq('id', testPaymentId)
        .select();
      
      if (updateError1) {
        console.log('❌ UPDATE FAILED with 11837.30:');
        console.log(`   Error: ${updateError1.message}`);
        console.log(`   Code: ${updateError1.code}`);
        console.log(`   Details: ${JSON.stringify(updateError1.details, null, 2)}`);
        console.log(`   Hint: ${updateError1.hint}`);
      } else {
        console.log('✅ UPDATE SUCCEEDED with 11837.30');
        console.log(`   New Final Amount: ${updateTest1[0].final_bill_amount}`);
      }
      
      // Test with the working value
      console.log('\n🧪 ATTEMPTING TEST UPDATE (11000.37 GRR):');
      console.log('='.repeat(80));
      
      const { data: updateTest2, error: updateError2 } = await supabase
        .from('vendor_payment_schedule')
        .update({
          grr_amount: 11000.37,
          final_bill_amount: 22401.25 - 11000.37 // 11400.88
        })
        .eq('id', testPaymentId)
        .select();
      
      if (updateError2) {
        console.log('❌ UPDATE FAILED with 11000.37:');
        console.log(`   Error: ${updateError2.message}`);
      } else {
        console.log('✅ UPDATE SUCCEEDED with 11000.37');
        console.log(`   New Final Amount: ${updateTest2[0].final_bill_amount}`);
      }
    }

    // Query 4: List all constraints on the table
    console.log('\n\n🔐 ALL CONSTRAINTS ON TABLE:');
    console.log('='.repeat(80));
    
    const { data: allConstraints, error: allError } = await supabase
      .from('information_schema.table_constraints')
      .select('*')
      .eq('table_name', 'vendor_payment_schedule')
      .eq('table_schema', 'public');
    
    if (allError) {
      console.log('❌ Error:', allError.message);
    } else {
      console.log(`\nFound ${allConstraints?.length || 0} constraints:`);
      allConstraints?.forEach((constraint, idx) => {
        console.log(`\n${idx + 1}. ${constraint.constraint_name}`);
        console.log(`   Type: ${constraint.constraint_type}`);
      });
    }

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

// Run the check
checkVendorPaymentConstraints()
  .then(() => {
    console.log('\n\n✅ Constraint check completed');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });
