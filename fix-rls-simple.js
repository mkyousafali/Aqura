// Fix RLS policies by enabling public read access
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

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  db: { schema: 'public' },
  auth: { persistSession: false }
});

async function fixRLS() {
  console.log('🔧 Fixing RLS policies...\n');

  try {
    // Fix offer_bundles
    console.log('📦 Fixing offer_bundles...');
    
    const { data: d1, error: e1 } = await supabase
      .from('offer_bundles')
      .select('count');
    
    if (e1) {
      console.log('Current error with anon:', e1.message);
    }

    // Create policy using direct SQL through a function
    const sql1 = `
      DROP POLICY IF EXISTS "allow_public_read_bundles" ON offer_bundles;
      CREATE POLICY "allow_public_read_bundles"
      ON offer_bundles
      FOR SELECT
      TO anon, authenticated
      USING (true);
    `;

    console.log('Executing SQL for bundles...');
    const { error: sqlError1 } = await supabase.rpc('execute_sql', { sql_query: sql1 });
    
    if (sqlError1) {
      console.log('RPC not available, trying direct query...');
      // Try alternative approach
      const { error: altError1 } = await supabase
        .from('offer_bundles')
        .select('*')
        .limit(0); // This will fail but tell us the RLS state
      
      console.log('Alternative check:', altError1?.message || 'OK');
    } else {
      console.log('✅ Bundle policy created');
    }

    // Fix bogo_offer_rules
    console.log('\n🎁 Fixing bogo_offer_rules...');
    
    const sql2 = `
      DROP POLICY IF EXISTS "allow_public_read_bogo" ON bogo_offer_rules;
      CREATE POLICY "allow_public_read_bogo"
      ON bogo_offer_rules
      FOR SELECT
      TO anon, authenticated
      USING (true);
    `;

    const { error: sqlError2 } = await supabase.rpc('execute_sql', { sql_query: sql2 });
    
    if (sqlError2) {
      console.log('RPC not available for BOGO');
    } else {
      console.log('✅ BOGO policy created');
    }

    console.log('\n📊 Testing with anon key...');
    
    const supabaseAnon = createClient(supabaseUrl, envVars.VITE_SUPABASE_ANON_KEY);

    const { data: testBundles, error: testError1 } = await supabaseAnon
      .from('offer_bundles')
      .select('*')
      .eq('offer_id', 17);
    
    console.log('Bundle test:', testError1 ? `Error: ${testError1.message}` : `Success: ${testBundles?.length} records`);

    const { data: testBogo, error: testError2 } = await supabaseAnon
      .from('bogo_offer_rules')
      .select('*')
      .eq('offer_id', 19);
    
    console.log('BOGO test:', testError2 ? `Error: ${testError2.message}` : `Success: ${testBogo?.length} records`);

  } catch (err) {
    console.error('Error:', err.message);
  }
}

fixRLS().catch(console.error);
