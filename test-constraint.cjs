const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function testConstraint() {
  console.log('🧪 Testing constraint logic...\n');
  
  // Get the specific record that's failing
  const { data: record, error } = await supabase
    .from('vendor_payment_schedule')
    .select('*')
    .eq('id', 'af500080-2d7e-42b7-aa7b-adee12770047')
    .single();

  if (error) {
    console.error('❌ Error fetching record:', error);
    return;
  }

  console.log('📋 Current record state:');
  console.log('- bill_amount:', record.bill_amount);
  console.log('- final_bill_amount:', record.final_bill_amount);
  console.log('- discount_amount:', record.discount_amount);
  console.log('- grr_amount:', record.grr_amount);
  console.log('- pri_amount:', record.pri_amount);
  console.log('- original_bill_amount:', record.original_bill_amount);
  console.log('- original_final_amount:', record.original_final_amount);
  
  const totalDeductions = (record.discount_amount || 0) + (record.grr_amount || 0) + (record.pri_amount || 0);
  const expectedFinal = record.bill_amount - totalDeductions;
  
  console.log('\n📊 Calculation:');
  console.log('- Total deductions:', totalDeductions);
  console.log('- Expected final_bill_amount:', expectedFinal);
  console.log('- Current final_bill_amount:', record.final_bill_amount);
  console.log('- Match:', record.final_bill_amount === expectedFinal);
  
  console.log('\n✅ Constraint formula:');
  console.log('final_bill_amount = bill_amount - (discount_amount + grr_amount + pri_amount)');
  console.log(`${record.final_bill_amount} = ${record.bill_amount} - (${record.discount_amount} + ${record.grr_amount} + ${record.pri_amount})`);
  
  // Test what happens if we try to update with GRR
  console.log('\n🧪 Testing update with GRR = 11837.30:');
  const newGrr = 11837.30;
  const newFinal = record.bill_amount - newGrr;
  
  console.log('- bill_amount:', record.bill_amount);
  console.log('- New GRR:', newGrr);
  console.log('- Calculated new final:', newFinal);
  console.log('- Formula:', `${newFinal} = ${record.bill_amount} - ${newGrr}`);
}

testConstraint().catch(console.error);
