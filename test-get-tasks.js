// Test get_tasks_for_receiving_record function
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testGetTasks() {
  const receiving_record_id = 'd378fddd-9185-4c2a-983f-8227d2a1715f'; // Latest one from your logs
  
  console.log('Testing get_tasks_for_receiving_record function...');
  console.log('Receiving record ID:', receiving_record_id);
  
  const { data, error } = await supabase.rpc('get_tasks_for_receiving_record', {
    receiving_record_id_param: receiving_record_id
  });
  
  if (error) {
    console.error('❌ Error:', error);
    console.error('Error details:', JSON.stringify(error, null, 2));
  } else {
    console.log('✅ Success!');
    console.log('Tasks found:', data?.length || 0);
    console.log('Data:', JSON.stringify(data, null, 2));
  }
}

testGetTasks().then(() => process.exit(0)).catch(err => {
  console.error('Test failed:', err);
  process.exit(1);
});
