import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkData() {
  console.log('Checking hr_fingerprint_transactions with service role key...\n');

  // Use service role key to bypass RLS
  const { data, error, count } = await supabase
    .from('hr_fingerprint_transactions')
    .select('*', { count: 'exact' })
    .limit(5);

  if (error) {
    console.error('❌ Error:', error);
    
    // Try a direct insert test
    console.log('\nTrying test insert...');
    const testData = {
      employee_id: 'TEST123',
      name: 'Test Employee',
      date: '2025-11-28',
      time: '16:00:00',
      status: 'Check In',
      device_id: 'TEST',
      location: 'Test Location',
      branch_id: 3
    };
    
    const { data: insertData, error: insertError } = await supabase
      .from('hr_fingerprint_transactions')
      .insert(testData)
      .select();
    
    if (insertError) {
      console.error('❌ Insert error:', insertError);
    } else {
      console.log('✅ Insert succeeded:', insertData);
    }
  } else {
    console.log(`📊 Total records: ${count}`);
    
    if (count > 0) {
      console.log('\n✅ Data exists! Sample:');
      data.forEach((r, i) => {
        console.log(`${i + 1}. ${r.employee_id} - ${r.date} ${r.time} - ${r.status}`);
      });
    } else {
      console.log('\n❌ Table is empty despite successful sync!');
      console.log('Checking for silent insert failures...');
    }
  }
}

checkData();
