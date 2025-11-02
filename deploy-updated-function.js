import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

const supabase = createClient(
  'https://vmypotfsyrvuublyddyt.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ'
);

async function deployFunction() {
  try {
    const sql = fs.readFileSync('./supabase/migrations/process_clearance_certificate_generation.sql', 'utf8');
    
    console.log('📤 Deploying updated function...');
    
    const { data, error } = await supabase.rpc('exec_sql', { sql_query: sql });
    
    if (error) {
      console.error('❌ Error deploying function:', error);
      process.exit(1);
    }
    
    console.log('✅ Function deployed successfully!');
    console.log(JSON.stringify(data, null, 2));
    
  } catch (err) {
    console.error('❌ Exception:', err.message);
    process.exit(1);
  }
}

deployFunction();
