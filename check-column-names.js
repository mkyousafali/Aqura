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

async function checkColumns() {
  console.log('\n=== OFFER_BUNDLES COLUMNS ===');
  const { data: bundle } = await supabase
    .from('offer_bundles')
    .select('*')
    .limit(1)
    .single();
  
  if (bundle) {
    console.log('Columns:', Object.keys(bundle));
    console.log('Data:', bundle);
  }

  console.log('\n=== BOGO_OFFER_RULES COLUMNS ===');
  const { data: bogo } = await supabase
    .from('bogo_offer_rules')
    .select('*')
    .limit(1)
    .single();
  
  if (bogo) {
    console.log('Columns:', Object.keys(bogo));
    console.log('Data:', bogo);
  }
}

checkColumns().then(() => {
  console.log('\n✅ Done');
  process.exit(0);
});
