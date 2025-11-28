const { readFileSync } = require('fs');
const { createClient } = require('@supabase/supabase-js');

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

const supabaseUrl = envVars.PUBLIC_SUPABASE_URL;
const supabaseServiceKey = envVars.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function createBiometricConnectionsTable() {
  try {
    console.log('🔧 Creating biometric_connections table in Supabase...\n');

    // SQL to create table
    const createTableSQL = `
-- Create biometric_connections table
CREATE TABLE IF NOT EXISTS biometric_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id INTEGER NOT NULL REFERENCES branches(id),
  branch_name TEXT NOT NULL,
  server_ip TEXT NOT NULL,
  server_name TEXT,
  database_name TEXT NOT NULL,
  username TEXT NOT NULL,
  password TEXT NOT NULL,
  device_id TEXT NOT NULL,
  terminal_sn TEXT,
  is_active BOOLEAN DEFAULT true,
  last_sync_at TIMESTAMPTZ,
  last_employee_sync_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_branch_device UNIQUE(branch_id, device_id)
);

-- Enable RLS
ALTER TABLE biometric_connections ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Enable read for authenticated users" ON biometric_connections
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Enable insert for authenticated users" ON biometric_connections
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable update for authenticated users" ON biometric_connections
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Enable delete for authenticated users" ON biometric_connections
  FOR DELETE USING (auth.role() = 'authenticated');

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_biometric_connections_branch ON biometric_connections(branch_id);
CREATE INDEX IF NOT EXISTS idx_biometric_connections_active ON biometric_connections(is_active);
CREATE INDEX IF NOT EXISTS idx_biometric_connections_device ON biometric_connections(device_id);
`;

    console.log('📋 SQL Statement:');
    console.log('=' .repeat(80));
    console.log(createTableSQL);
    console.log('=' .repeat(80));
    console.log('\n⚠️  NOTE: This SQL needs to be executed in Supabase SQL Editor');
    console.log('\nSteps:');
    console.log('1. Go to Supabase Dashboard: https://supabase.com/dashboard');
    console.log('2. Select your project');
    console.log('3. Go to SQL Editor');
    console.log('4. Create new query');
    console.log('5. Copy and paste the SQL above');
    console.log('6. Click "Run"');
    console.log('\n✅ After running, verify with:');
    console.log('   SELECT * FROM biometric_connections;');

    // Try to verify if table already exists
    console.log('\n🔍 Checking if table already exists...\n');
    
    const { data, error } = await supabase
      .from('biometric_connections')
      .select('*')
      .limit(1);

    if (error) {
      if (error.message.includes('relation') && error.message.includes('does not exist')) {
        console.log('❌ Table does not exist yet. Please create it using the SQL above.');
      } else {
        console.log('⚠️  Error checking table:', error.message);
      }
    } else {
      console.log('✅ Table already exists!');
      console.log(`   Current records: ${data ? data.length : 0}`);
    }

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

createBiometricConnectionsTable();
