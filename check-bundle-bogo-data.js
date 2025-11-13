// Check all bundle and BOGO data
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

async function checkData() {
  console.log('🔍 Checking all bundle and BOGO data...\n');

  // Check offer_bundles table
  console.log('📦 All records in offer_bundles:');
  const { data: allBundles, error: bundlesError, count: bundlesCount } = await supabase
    .from('offer_bundles')
    .select('*', { count: 'exact' });
  
  if (bundlesError) {
    console.error('❌ Error:', bundlesError);
  } else {
    console.log(`✅ Total records: ${bundlesCount}`);
    console.log(JSON.stringify(allBundles, null, 2));
  }

  console.log('\n---\n');

  // Check bogo_offer_rules table
  console.log('🎁 All records in bogo_offer_rules:');
  const { data: allBogo, error: bogoError, count: bogoCount } = await supabase
    .from('bogo_offer_rules')
    .select('*', { count: 'exact' });
  
  if (bogoError) {
    console.error('❌ Error:', bogoError);
  } else {
    console.log(`✅ Total records: ${bogoCount}`);
    console.log(JSON.stringify(allBogo, null, 2));
  }

  console.log('\n---\n');

  // Check all offers with their types
  console.log('🎁 All active offers:');
  const { data: allOffers, error: offersError } = await supabase
    .from('offers')
    .select('id, type, name_en, is_active, show_in_carousel')
    .eq('is_active', true);
  
  if (offersError) {
    console.error('❌ Error:', offersError);
  } else {
    console.log(JSON.stringify(allOffers, null, 2));
  }
}

checkData().catch(console.error);
