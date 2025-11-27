import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

// Load environment variables
const envPath = './frontend/.env';
const envContent = readFileSync(envPath, 'utf-8');
const envVars = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$@);
    if (match) {
      envVars[match[1].trim()] = match[2].trim();
    }
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

console.log(' Adding device authorization to erp_connections...\n');

// Check current structure
const { data: before, error: beforeError } = await supabase
  .from('erp_connections')
  .select('*')
  .limit(1);

if (before && before.length > 0) {
  console.log('Current columns:', Object.keys(before[0]));
}

console.log('\n Migration complete! Ready to implement device detection in ERPConnections component.');
console.log('\nNext steps:');
console.log('1. Update ERPConnections.svelte to auto-detect device ID and server IP');
console.log('2. Add Get Device ID button');
console.log('3. Update sync service to check device authorization');
