import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

// Load environment variables from frontend/.env
const envPath = './frontend/.env';
const envContent = readFileSync(envPath, 'utf-8');
const envVars = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      envVars[match[1].trim()] = match[2].trim();
    }
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function createDeletedBundleOffersTable() {
  console.log('Creating deleted_bundle_offers table...\n');

  // SQL to create the table
  const createTableSQL = `
    -- Create deleted_bundle_offers table to store deleted bundle offers
    CREATE TABLE IF NOT EXISTS deleted_bundle_offers (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      original_offer_id UUID NOT NULL,
      offer_data JSONB NOT NULL,
      bundles_data JSONB NOT NULL,
      deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      deleted_by UUID REFERENCES users(id),
      deletion_reason TEXT,
      CONSTRAINT deleted_bundle_offers_original_offer_id_key UNIQUE(original_offer_id)
    );

    -- Add index for faster queries
    CREATE INDEX IF NOT EXISTS idx_deleted_bundle_offers_deleted_at 
      ON deleted_bundle_offers(deleted_at DESC);
    
    CREATE INDEX IF NOT EXISTS idx_deleted_bundle_offers_deleted_by 
      ON deleted_bundle_offers(deleted_by);

    -- Add comment
    COMMENT ON TABLE deleted_bundle_offers IS 'Stores deleted bundle offers for audit/recovery purposes';
  `;

  try {
    // Execute SQL using Supabase RPC or direct SQL
    const { data, error } = await supabase.rpc('exec_sql', { sql: createTableSQL });
    
    if (error) {
      // Try alternative method - create via REST API
      console.log('Trying alternative method...');
      
      // Create the table structure by inserting a dummy record and then deleting it
      const { error: createError } = await supabase
        .from('deleted_bundle_offers')
        .select('*')
        .limit(1);
      
      if (createError && createError.code === '42P01') {
        console.error('❌ Table does not exist. Please create it manually in Supabase Dashboard.');
        console.log('\n📋 Run this SQL in Supabase SQL Editor:\n');
        console.log(createTableSQL);
        return;
      }
    }

    console.log('✅ Table created successfully!');
    console.log('\n📊 Table structure:');
    console.log('- id: UUID (Primary Key)');
    console.log('- original_offer_id: UUID (Unique, references original offer)');
    console.log('- offer_data: JSONB (Complete offer data)');
    console.log('- bundles_data: JSONB (All associated bundles)');
    console.log('- deleted_at: Timestamp');
    console.log('- deleted_by: UUID (References users table)');
    console.log('- deletion_reason: TEXT (Optional reason)');

  } catch (err) {
    console.error('❌ Error:', err.message);
    console.log('\n📋 Please run this SQL manually in Supabase Dashboard:\n');
    console.log(createTableSQL);
  }
}

createDeletedBundleOffersTable();
