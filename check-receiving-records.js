// Check receiving_records table structure
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkReceivingRecords() {
  console.log('Checking receiving_records table structure...');
  
  // Get first record to see the structure
  const { data, error } = await supabase
    .from('receiving_records')
    .select('*')
    .limit(1);
  
  if (error) {
    console.error('❌ Error:', error);
  } else if (data && data.length > 0) {
    console.log('✅ Receiving record structure:', Object.keys(data[0]));
    console.log('\nSample record:', data[0]);
    
    // Find user-related fields
    const userFields = Object.keys(data[0]).filter(key => key.includes('user'));
    console.log('\n📋 User-related fields:', userFields);
  } else {
    console.log('No receiving records found');
  }
}

checkReceivingRecords().then(() => process.exit(0)).catch(err => {
  console.error('Failed:', err);
  process.exit(1);
});
