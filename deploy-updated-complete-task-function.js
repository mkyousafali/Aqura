// Deploy updated complete_receiving_task function
import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

// Configuration
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

// Create Supabase client with service role key
const supabase = createClient(supabaseUrl, serviceRoleKey);

async function deployFunction() {
  console.log('🚀 DEPLOYING UPDATED complete_receiving_task FUNCTION');
  console.log('==================================================\n');

  try {
    // Read the SQL file
    const sqlContent = fs.readFileSync('./supabase/migrations/complete_receiving_task.sql', 'utf8');
    
    console.log('📝 Executing SQL migration...\n');
    
    // Execute the SQL
    const { data, error } = await supabase.rpc('exec_sql', {
      sql: sqlContent
    });

    if (error) {
      console.error('❌ Error deploying function:', error);
      return;
    }

    console.log('✅ Function deployed successfully!');
    console.log('📋 Result:', data);

    // Test the function exists
    console.log('\n🔍 Verifying function deployment...\n');
    
    const { data: functionInfo, error: checkError } = await supabase.rpc('exec_sql', {
      sql: `
        SELECT proname, pg_get_functiondef(oid) as definition
        FROM pg_proc 
        WHERE proname = 'complete_receiving_task'
        LIMIT 1;
      `
    });

    if (checkError) {
      console.error('❌ Error checking function:', checkError);
    } else if (functionInfo && functionInfo.length > 0) {
      console.log('✅ Function verification successful!');
      console.log(`   Function name: ${functionInfo[0].proname}`);
      console.log(`   Definition length: ${functionInfo[0].definition.length} characters`);
    } else {
      console.log('⚠️ Function not found after deployment');
    }

    console.log('\n✅ Deployment completed successfully!');

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

// Run the deployment
deployFunction();