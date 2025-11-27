import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

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

console.log(' Adding allowed_device_id column to erp_connections...\n');

// Add allowed_device_id column
const { error: alterError } = await supabase.rpc('exec_sql', {
  query: `ALTER TABLE erp_connections ADD COLUMN IF NOT EXISTS allowed_device_id TEXT;`
});

if (alterError) {
  console.error(' Error adding column:', alterError.message);
} else {
  console.log(' Column added successfully');
}

// Create index
const { error: indexError } = await supabase.rpc('exec_sql', {
  query: `CREATE INDEX IF NOT EXISTS idx_erp_connections_device_id ON erp_connections(allowed_device_id);`
});

if (indexError) {
  console.error(' Error creating index:', indexError.message);
} else {
  console.log(' Index created successfully');
}

// Verify the change
const { data, error } = await supabase
  .from('erp_connections')
  .select('*')
  .limit(1);

if (error) {
  console.error(' Verification error:', error.message);
} else {
  console.log('\n Current table structure:');
  if (data && data.length > 0) {
    console.log('Columns:', Object.keys(data[0]));
  }
}
