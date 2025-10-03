// Create push subscriptions table using Supabase client
import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function createTable() {
  console.log('📦 Creating push_subscriptions table...');

  // Create table SQL
  const createTableSQL = `
    CREATE TABLE IF NOT EXISTS push_subscriptions (
        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
        user_id UUID NOT NULL,
        device_id VARCHAR(255) NOT NULL UNIQUE,
        push_subscription JSONB NOT NULL,
        device_type VARCHAR(20) CHECK (device_type IN ('mobile', 'desktop')),
        browser_name VARCHAR(50),
        user_agent TEXT,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        last_seen TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
  `;

  try {
    const { error: tableError } = await supabase.rpc('exec_sql', { 
      sql: createTableSQL 
    });

    if (tableError) {
      console.log('Table creation result:', tableError);
    } else {
      console.log('✅ Table created successfully');
    }

    // Create indexes
    const indexSQL = `
      CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON push_subscriptions(user_id);
      CREATE INDEX IF NOT EXISTS idx_push_subscriptions_device_id ON push_subscriptions(device_id);
      CREATE INDEX IF NOT EXISTS idx_push_subscriptions_active ON push_subscriptions(is_active) WHERE is_active = true;
    `;

    const { error: indexError } = await supabase.rpc('exec_sql', { 
      sql: indexSQL 
    });

    if (!indexError) {
      console.log('✅ Indexes created successfully');
    }

    // Test if table exists by selecting from it
    const { data, error } = await supabase
      .from('push_subscriptions')
      .select('count')
      .limit(1);

    if (!error) {
      console.log('✅ Table verified - ready for use!');
    } else {
      console.log('❌ Table verification failed:', error.message);
    }

  } catch (error) {
    console.error('❌ Failed to create table:', error.message);
    console.log('\n📋 Manual SQL to run in Supabase Dashboard:');
    console.log('Go to: https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt/sql');
    console.log('Run this SQL:');
    console.log(createTableSQL);
  }
}

createTable();