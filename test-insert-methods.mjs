import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function testInsert() {
  console.log('Testing direct insert...\n');

  const testData = {
    employee_id: '12345',
    name: 'Test Employee',
    date: '2025-11-27',
    time: '10:30:00',
    status: 'Check In',
    device_id: 'DEVICE001',
    location: 'Main Office',
    branch_id: 3
  };

  // Try direct insert (not upsert)
  const { data, error } = await supabase
    .from('hr_fingerprint_transactions')
    .insert([testData])
    .select();

  if (error) {
    console.error('❌ Insert error:', error.message);
    console.log('Error details:', JSON.stringify(error, null, 2));
  } else {
    console.log('✅ Insert succeeded!');
    console.log('Data:', data);
  }

  // Now try upsert with conflict target
  console.log('\nTesting upsert with conflict target...\n');
  
  const { data: upsertData, error: upsertError } = await supabase
    .from('hr_fingerprint_transactions')
    .upsert([testData], {
      onConflict: 'employee_id,date,time',
      ignoreDuplicates: true
    })
    .select();

  if (upsertError) {
    console.error('❌ Upsert error:', upsertError.message);
    console.log('Error code:', upsertError.code);
    console.log('This means: The unique constraint for (employee_id,date,time) does NOT exist!');
  } else {
    console.log('✅ Upsert succeeded!');
    console.log('Data:', upsertData);
  }
}

testInsert();
