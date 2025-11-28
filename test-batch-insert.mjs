import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function testBatchInsert() {
  console.log('Testing batch insert with service role key...\n');

  // Create test batch similar to sync app
  const testBatch = [];
  for (let i = 0; i < 5; i++) {
    testBatch.push({
      employee_id: `TEST${i}`,
      name: null,
      date: '2025-11-27',
      time: `10:${String(i).padStart(2, '0')}:00`,
      status: 'Check In',
      device_id: 'TESTDEVICE',
      location: 'Test Location',
      branch_id: 3,
      created_at: new Date().toISOString()
    });
  }

  console.log('Test batch:');
  console.log(JSON.stringify(testBatch[0], null, 2));
  console.log(`\nInserting ${testBatch.length} records...\n`);

  const { data, error } = await supabase
    .from('hr_fingerprint_transactions')
    .insert(testBatch)
    .select();

  if (error) {
    console.error('❌ INSERT FAILED:');
    console.error('Message:', error.message);
    console.error('Code:', error.code);
    console.error('Details:', error.details);
    console.error('Hint:', error.hint);
  } else {
    console.log(`✅ SUCCESS! Inserted ${data?.length || 0} records`);
    console.log('Returned data:', data);
  }

  // Check table count
  console.log('\n\nChecking table count...');
  const { count } = await supabase
    .from('hr_fingerprint_transactions')
    .select('*', { count: 'exact', head: true });
  
  console.log(`Total records in table: ${count}`);
}

testBatchInsert();
