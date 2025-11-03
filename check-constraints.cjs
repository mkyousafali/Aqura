const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  db: {
    schema: 'public'
  }
});

async function checkConstraints() {
  console.log('🔍 Checking constraints on vendor_payment_schedule table...\n');
  
  // Query pg_catalog to get constraints
  const { data, error } = await supabase.rpc('sql', {
    query: `
      SELECT 
        conname AS constraint_name,
        contype AS constraint_type,
        pg_get_constraintdef(oid) AS constraint_definition
      FROM pg_constraint
      WHERE conrelid = 'vendor_payment_schedule'::regclass
      AND contype = 'c'
      ORDER BY conname;
    `
  });

  if (error) {
    console.log('⚠️ RPC method not available, trying direct query...');
    
    // Try using a custom query approach
    const query = `
      SELECT 
        con.conname AS constraint_name,
        con.contype AS constraint_type,
        pg_get_constraintdef(con.oid) AS constraint_definition
      FROM pg_constraint con
      JOIN pg_class rel ON rel.oid = con.conrelid
      JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
      WHERE rel.relname = 'vendor_payment_schedule'
        AND nsp.nspname = 'public'
        AND con.contype = 'c'
      ORDER BY con.conname;
    `;
    
    console.log('Query:', query);
    console.log('\n❌ Cannot execute raw SQL without a custom RPC function');
    console.log('Constraint info from error message: "check_total_deductions_valid"');
    console.log('\nThis constraint likely checks that:');
    console.log('- discount_amount + grr_amount + pri_amount <= bill_amount');
    console.log('- OR final_bill_amount = bill_amount - (discount_amount + grr_amount + pri_amount)');
    
    // Let's test the constraint by trying different scenarios
    console.log('\n🧪 Testing constraint logic...\n');
    
    // Get a sample record
    const { data: sample } = await supabase
      .from('vendor_payment_schedule')
      .select('*')
      .limit(1)
      .single();
    
    if (sample) {
      const totalDeductions = (sample.discount_amount || 0) + (sample.grr_amount || 0) + (sample.pri_amount || 0);
      const expectedFinal = sample.bill_amount - totalDeductions;
      
      console.log('Sample record analysis:');
      console.log('- bill_amount:', sample.bill_amount);
      console.log('- discount_amount:', sample.discount_amount);
      console.log('- grr_amount:', sample.grr_amount);
      console.log('- pri_amount:', sample.pri_amount);
      console.log('- Total deductions:', totalDeductions);
      console.log('- final_bill_amount:', sample.final_bill_amount);
      console.log('- Expected final:', expectedFinal);
      console.log('- Match:', sample.final_bill_amount === expectedFinal);
      
      console.log('\n📝 Constraint Rule:');
      console.log('final_bill_amount MUST equal bill_amount - (discount_amount + grr_amount + pri_amount)');
    }
  } else {
    console.log('✅ Constraints found:');
    console.log(JSON.stringify(data, null, 2));
  }
}

checkConstraints().catch(console.error);
