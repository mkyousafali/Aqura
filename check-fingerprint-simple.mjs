import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkFingerprint() {
  console.log('Checking hr_fingerprint_transactions table...\n');

  // Check total count
  const { data, error, count } = await supabase
    .from('hr_fingerprint_transactions')
    .select('*', { count: 'exact' })
    .limit(5);

  if (error) {
    console.error('❌ Error:', error.message);
    console.error('Details:', error);
    return;
  }

  console.log(`📊 Total records: ${count}`);
  
  if (count === 0) {
    console.log('\n❌ Table is EMPTY!');
    console.log('\nChecking table structure...');
    
    // Try a test insert
    const testData = {
      employee_id: 'TEST123',
      date: '2025-11-28',
      time: '16:00:00',
      status: 'Check In',
      device_id: 'TEST',
      location: 'Test',
      branch_id: 3
    };
    
    console.log('\nTrying test insert...');
    const { data: insertData, error: insertError } = await supabase
      .from('hr_fingerprint_transactions')
      .insert(testData)
      .select();
    
    if (insertError) {
      console.error('❌ Insert failed:', insertError.message);
      console.error('Details:', insertError);
    } else {
      console.log('✅ Test insert succeeded!');
      console.log('Inserted:', insertData);
      
      // Clean up
      await supabase
        .from('hr_fingerprint_transactions')
        .delete()
        .eq('employee_id', 'TEST123');
      
      console.log('\n💡 The table works! Issue is with the sync app data format.');
    }
  } else {
    console.log('\n✅ Sample records:');
    data.forEach((record, i) => {
      console.log(`\nRecord ${i + 1}:`);
      console.log('  Employee ID:', record.employee_id);
      console.log('  Date:', record.date);
      console.log('  Time:', record.time);
      console.log('  Status:', record.status);
      console.log('  Device:', record.device_id);
    });
  }
}

checkFingerprint();
