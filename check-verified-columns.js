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

const recordId = 'be756959-816d-4eaf-84d4-07926162b61d';

console.log('🔍 Checking for verification columns in receiving_records...\n');

const { data, error } = await supabase
  .from('receiving_records')
  .select('*')
  .eq('id', recordId)
  .single();

if (error) {
  console.error('❌ Error:', error);
} else {
  const columns = Object.keys(data);
  const verifiedCols = columns.filter(c => c.toLowerCase().includes('verif'));
  
  console.log('📋 Columns containing "verif":');
  if (verifiedCols.length > 0) {
    verifiedCols.forEach(col => {
      console.log(`  ✓ ${col}: ${data[col]}`);
    });
  } else {
    console.log('  ❌ No verification columns found');
  }
  
  console.log('\n📋 All columns:', columns.join(', '));
}
