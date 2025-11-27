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

console.log(' Checking erp_connections table structure...\n');

// Check current structure
const { data, error } = await supabase
  .from('erp_connections')
  .select('*')
  .limit(1);

if (error) {
  console.error(' Error:', error.message);
} else {
  console.log(' Current columns in erp_connections:');
  if (data && data.length > 0) {
    Object.keys(data[0]).forEach(col => console.log(   - ));
  }
  
  console.log('\n Current data:');
  console.log(JSON.stringify(data[0], null, 2));
}

console.log('\n To add allowed_device_id column, run this SQL in Supabase Dashboard:');
console.log('   ALTER TABLE erp_connections ADD COLUMN IF NOT EXISTS allowed_device_id TEXT;');
console.log('   CREATE INDEX IF NOT EXISTS idx_erp_connections_device_id ON erp_connections(allowed_device_id);');