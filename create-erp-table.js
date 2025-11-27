import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

// Load environment variables
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

console.log('🔌 Creating erp_connections table in Supabase...\n');

const migrationSQL = `
-- Create erp_connections table
CREATE TABLE IF NOT EXISTS erp_connections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    branch_name TEXT NOT NULL,
    server_ip TEXT NOT NULL,
    server_name TEXT,
    database_name TEXT NOT NULL,
    username TEXT NOT NULL,
    password TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(branch_id)
);

-- Add RLS policies
ALTER TABLE erp_connections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read ERP connections" ON erp_connections;
CREATE POLICY "Allow authenticated users to read ERP connections"
    ON erp_connections
    FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Allow authenticated users to create ERP connections" ON erp_connections;
CREATE POLICY "Allow authenticated users to create ERP connections"
    ON erp_connections
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated users to update ERP connections" ON erp_connections;
CREATE POLICY "Allow authenticated users to update ERP connections"
    ON erp_connections
    FOR UPDATE
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Allow authenticated users to delete ERP connections" ON erp_connections;
CREATE POLICY "Allow authenticated users to delete ERP connections"
    ON erp_connections
    FOR DELETE
    TO authenticated
    USING (true);

-- Add updated_at trigger function if not exists
CREATE OR REPLACE FUNCTION update_erp_connections_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_erp_connections_updated_at ON erp_connections;
CREATE TRIGGER update_erp_connections_updated_at
    BEFORE UPDATE ON erp_connections
    FOR EACH ROW
    EXECUTE FUNCTION update_erp_connections_updated_at();

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_erp_connections_branch_id ON erp_connections(branch_id);
CREATE INDEX IF NOT EXISTS idx_erp_connections_is_active ON erp_connections(is_active);
`;

try {
  const { data, error } = await supabase.rpc('exec_sql', {
    sql_query: migrationSQL
  });

  if (error) {
    // Try direct execution as fallback
    console.log('Attempting direct execution...');
    const statements = migrationSQL.split(';').filter(s => s.trim());
    
    for (const statement of statements) {
      if (statement.trim()) {
        try {
          await supabase.from('_sql').select().limit(0); // Dummy query to test connection
          console.log('Note: Direct SQL execution not available via client library');
          console.log('\nPlease run this SQL manually in Supabase SQL Editor:');
          console.log('\n' + migrationSQL);
          break;
        } catch (e) {
          // Expected
        }
      }
    }
  } else {
    console.log('✅ Table created successfully!');
  }

  // Verify table exists
  const { data: tableData, error: tableError } = await supabase
    .from('erp_connections')
    .select('*')
    .limit(1);

  if (!tableError) {
    console.log('✅ Table verification successful!');
    console.log(`   Current records: ${tableData?.length || 0}`);
  } else {
    console.log('\n⚠️  Please run the migration SQL manually in Supabase Dashboard:');
    console.log('   1. Go to Supabase Dashboard > SQL Editor');
    console.log('   2. Create a new query');
    console.log('   3. Copy the SQL from: supabase/migrations/create_erp_connections_table.sql');
    console.log('   4. Run the query');
  }

} catch (error) {
  console.error('❌ Error:', error.message);
  console.log('\n⚠️  Please run the migration SQL manually in Supabase Dashboard');
}
