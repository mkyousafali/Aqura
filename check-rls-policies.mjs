import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkRLS() {
  console.log('Checking RLS policies...\n');

  // Check sales_data RLS
  const salesQuery = `
    SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
    FROM pg_policies 
    WHERE tablename = 'sales_data';
  `;

  // Check hr_fingerprint_transactions RLS
  const fingerQuery = `
    SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
    FROM pg_policies 
    WHERE tablename = 'hr_fingerprint_transactions';
  `;

  try {
    // Use raw SQL query
    const { data: salesPolicies, error: salesError } = await supabase
      .rpc('exec_raw_sql', { sql: salesQuery });
    
    const { data: fingerPolicies, error: fingerError } = await supabase
      .rpc('exec_raw_sql', { sql: fingerQuery });

    console.log('=== sales_data RLS Policies ===');
    if (salesError) {
      console.log('Cannot query (may need RPC function)');
    } else {
      console.log(JSON.stringify(salesPolicies, null, 2));
    }

    console.log('\n=== hr_fingerprint_transactions RLS Policies ===');
    if (fingerError) {
      console.log('Cannot query (may need RPC function)');
    } else {
      console.log(JSON.stringify(fingerPolicies, null, 2));
    }

  } catch (error) {
    console.error('Error:', error.message);
  }

  // Try direct insert with service role to test
  console.log('\n\n=== Testing Direct Insert (Service Role) ===\n');

  const testData = {
    employee_id: 'RLSTEST',
    name: 'RLS Test',
    date: '2025-11-28',
    time: '16:45:00',
    status: 'Check In',
    device_id: 'TEST',
    branch_id: 3
  };

  const { data, error } = await supabase
    .from('hr_fingerprint_transactions')
    .insert(testData)
    .select();

  if (error) {
    console.error('❌ Insert failed:', error.message);
    console.log('Error code:', error.code);
    console.log('Error details:', error.details);
    console.log('Error hint:', error.hint);
  } else {
    console.log('✅ Insert succeeded with service role!');
    console.log('Data:', data);
  }
}

checkRLS();
