import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkColumns() {
  console.log('🔍 Checking hr_fingerprint_transactions column structure...\n');

  // Query information_schema directly
  const { data, error } = await supabase.rpc('exec_sql', {
    query: `
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns 
      WHERE table_name = 'hr_fingerprint_transactions'
      ORDER BY ordinal_position;
    `
  });

  if (error) {
    console.error('❌ Error querying schema:', error);
    console.log('\nTrying alternative method...');
    
    // Try inserting to see what columns exist
    const testInsert = {
      employee_id: 'TEST',
      name: 'Test',
      date: '2025-11-28',
      time: '16:00:00',
      status: 'Check In',
      device_id: 'TEST',
      branch_id: 3
    };
    
    const { error: insertError } = await supabase
      .from('hr_fingerprint_transactions')
      .insert(testInsert);
    
    if (insertError) {
      console.error('❌ Insert error:', insertError.message);
      console.log('\nFull error details:', JSON.stringify(insertError, null, 2));
    }
  } else {
    console.log('✅ Current columns:');
    data.forEach(col => {
      console.log(`  - ${col.column_name} (${col.data_type})`);
    });
  }
}

checkColumns();
