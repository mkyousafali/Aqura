const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkTableStructure() {
  console.log('Checking hr_fingerprint_transactions structure...\n');

  // Query PostgreSQL information_schema
  const { data, error } = await supabase
    .rpc('get_table_columns', { p_table_name: 'hr_fingerprint_transactions' });

  if (error) {
    console.log('Trying direct query...');
    
    // Alternative: try a SELECT with no records to see column names
    const { data: emptyData, error: emptyError } = await supabase
      .from('hr_fingerprint_transactions')
      .select('*')
      .limit(0);
    
    if (!emptyError) {
      console.log('Table exists but has no standard columns exposed');
    }
    
    console.log('\nTrying SQL query for table structure...');
    const { data: cols, error: colError } = await supabase
      .rpc('exec_sql', { 
        query: `
          SELECT column_name, data_type, is_nullable
          FROM information_schema.columns
          WHERE table_name = 'hr_fingerprint_transactions'
          ORDER BY ordinal_position
        `
      });
    
    if (colError) {
      console.error('Cannot query table structure:', colError.message);
    } else {
      console.log('\n📋 Table columns:');
      cols.forEach(col => {
        console.log(`  - ${col.column_name} (${col.data_type}) ${col.is_nullable === 'YES' ? 'NULL' : 'NOT NULL'}`);
      });
    }
  } else {
    console.log('Columns:', data);
  }
}

checkTableStructure();
