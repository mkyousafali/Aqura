// Check existing tables in Supabase database
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function checkExistingTables() {
  console.log('🔍 Checking existing tables in your Supabase database...\n');

  try {
    // First, let's check if push_subscriptions table exists
    console.log('📋 Checking for push_subscriptions table...');
    const { data: pushSubsData, error: pushSubsError } = await supabase
      .from('push_subscriptions')
      .select('count')
      .limit(1);

    if (!pushSubsError) {
      console.log('✅ push_subscriptions table EXISTS');
      
      // Get table structure
      const { data: tableData, error: tableError } = await supabase
        .from('push_subscriptions')
        .select('*')
        .limit(1);
      
      if (tableData && tableData.length === 0) {
        console.log('   📊 Table is empty (ready for use)');
      } else if (tableData && tableData.length > 0) {
        console.log('   📊 Table has data:', tableData.length, 'records');
        console.log('   📝 Sample record structure:', Object.keys(tableData[0]));
      }
    } else {
      console.log('❌ push_subscriptions table does NOT exist');
      console.log('   Error:', pushSubsError.message);
    }

    // Check other relevant tables
    const tablesToCheck = [
      'users',
      'notifications', 
      'notification_recipients',
      'tasks',
      'task_assignments'
    ];

    console.log('\n📋 Checking other related tables...');
    
    for (const tableName of tablesToCheck) {
      try {
        const { data, error } = await supabase
          .from(tableName)
          .select('count')
          .limit(1);

        if (!error) {
          console.log(`✅ ${tableName} table EXISTS`);
        } else {
          console.log(`❌ ${tableName} table does NOT exist`);
        }
      } catch (err) {
        console.log(`❌ ${tableName} table does NOT exist or access denied`);
      }
    }

    // Check if we have any Edge Functions
    console.log('\n⚡ Checking Edge Functions...');
    try {
      const response = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          test: true
        })
      });

      if (response.status === 404) {
        console.log('❌ send-push-notification Edge Function does NOT exist');
      } else {
        console.log('✅ send-push-notification Edge Function EXISTS');
        console.log('   Status:', response.status);
      }
    } catch (error) {
      console.log('❌ send-push-notification Edge Function does NOT exist');
    }

    console.log('\n📊 Database Analysis Complete!');

  } catch (error) {
    console.error('❌ Failed to check database:', error.message);
  }
}

async function listAllTables() {
  console.log('\n🗂️  Attempting to list all tables...');
  
  // Try different approaches to list tables
  const queries = [
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'",
    "\\dt",
    "SELECT schemaname, tablename FROM pg_tables WHERE schemaname = 'public'"
  ];

  for (const query of queries) {
    try {
      console.log(`Trying query: ${query}`);
      // This might not work due to RLS, but worth trying
      const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/query`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
          'apikey': SERVICE_ROLE_KEY
        },
        body: JSON.stringify({ query })
      });

      if (response.ok) {
        const result = await response.json();
        console.log('Query result:', result);
        break;
      }
    } catch (error) {
      console.log('Query failed:', error.message);
    }
  }
}

// Run the checks
checkExistingTables().then(() => {
  listAllTables();
});