// Fix RLS policies for offer_bundles and bogo_offer_rules
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

async function fixRLSPolicies() {
  console.log('🔧 Fixing RLS policies for customer access...\n');

  // Fix offer_bundles RLS
  console.log('📦 Fixing offer_bundles RLS...');
  
  // Drop existing policy if exists
  const dropBundlePolicy = await supabase.rpc('exec_sql', {
    sql: `DROP POLICY IF EXISTS "allow_customers_read_bundles" ON offer_bundles;`
  });
  
  // Create new policy for bundles
  const createBundlePolicy = await supabase.rpc('exec_sql', {
    sql: `
      CREATE POLICY "allow_customers_read_bundles"
      ON offer_bundles
      FOR SELECT
      USING (true);
    `
  });
  
  console.log('✅ Bundle RLS policy created');

  // Fix bogo_offer_rules RLS
  console.log('\n🎁 Fixing bogo_offer_rules RLS...');
  
  // Drop existing policy if exists
  const dropBogoPolicy = await supabase.rpc('exec_sql', {
    sql: `DROP POLICY IF EXISTS "allow_customers_read_bogo_rules" ON bogo_offer_rules;`
  });
  
  // Create new policy for BOGO
  const createBogoPolicy = await supabase.rpc('exec_sql', {
    sql: `
      CREATE POLICY "allow_customers_read_bogo_rules"
      ON bogo_offer_rules
      FOR SELECT
      USING (true);
    `
  });
  
  console.log('✅ BOGO RLS policy created');

  console.log('\n🎉 RLS policies fixed! Testing access...\n');

  // Test with anon key
  const supabaseAnon = createClient(supabaseUrl, envVars.VITE_SUPABASE_ANON_KEY);

  // Test bundles
  const { data: testBundles, error: bundleError } = await supabaseAnon
    .from('offer_bundles')
    .select('*')
    .eq('offer_id', 17);
  
  console.log('📦 Test bundle access (anon key):');
  if (bundleError) {
    console.error('❌ Error:', bundleError);
  } else {
    console.log(`✅ Can read bundles: ${testBundles?.length || 0} records`);
  }

  // Test BOGO
  const { data: testBogo, error: bogoError } = await supabaseAnon
    .from('bogo_offer_rules')
    .select('*')
    .eq('offer_id', 19);
  
  console.log('\n🎁 Test BOGO access (anon key):');
  if (bogoError) {
    console.error('❌ Error:', bogoError);
  } else {
    console.log(`✅ Can read BOGO: ${testBogo?.length || 0} records`);
  }
}

fixRLSPolicies().catch(console.error);
