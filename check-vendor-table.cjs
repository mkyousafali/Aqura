const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function checkVendorPaymentSchedule() {
  console.log('🔍 Checking vendor_payment_schedule table...\n');
  
  // Get one record to see the structure
  const { data, error } = await supabase
    .from('vendor_payment_schedule')
    .select('*')
    .limit(1);

  if (error) {
    console.error('❌ Error:', error);
    return;
  }

  if (data && data.length > 0) {
    console.log('✅ Table columns:');
    console.log(Object.keys(data[0]).join(', '));
    console.log('\n📋 Sample record:');
    console.log(JSON.stringify(data[0], null, 2));
  } else {
    console.log('⚠️ No records found in table');
  }

  // Try to get table constraints info via raw SQL
  console.log('\n🔍 Checking table constraints...\n');
  
  const { data: constraints, error: constraintsError } = await supabase.rpc('exec_sql', {
    query: `
      SELECT 
        conname AS constraint_name,
        pg_get_constraintdef(c.oid) AS constraint_definition
      FROM pg_constraint c
      JOIN pg_namespace n ON n.oid = c.connamespace
      WHERE conrelid = 'public.vendor_payment_schedule'::regclass
      ORDER BY conname;
    `
  });

  if (constraintsError) {
    console.log('⚠️ Could not fetch constraints (function may not exist):', constraintsError.message);
    
    // Try alternative approach - get schema info
    console.log('\n📊 Trying to get column info...\n');
    
    const { data: columnInfo, error: colError } = await supabase
      .from('vendor_payment_schedule')
      .select('*')
      .limit(0);
    
    if (!colError) {
      console.log('Table accessible, checking for validation rules in code...');
    }
  } else {
    console.log('✅ Constraints:');
    console.log(JSON.stringify(constraints, null, 2));
  }

  // Check if there's a record with GRR to see the structure
  console.log('\n🔍 Looking for records with deductions...\n');
  
  const { data: withDeductions, error: dedError } = await supabase
    .from('vendor_payment_schedule')
    .select('*')
    .not('grr_amount', 'is', null)
    .limit(1);

  if (!dedError && withDeductions && withDeductions.length > 0) {
    console.log('✅ Found record with deductions:');
    console.log(JSON.stringify(withDeductions[0], null, 2));
  }
}

checkVendorPaymentSchedule().catch(console.error);
