import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

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
const supabaseAnonKey = envVars.VITE_SUPABASE_ANON_KEY;

// Test with ANON key (like the frontend does)
const supabase = createClient(supabaseUrl, supabaseAnonKey);

(async () => {
  console.log('\n🔍 Testing offer_products access with ANON key (like frontend)\n');
  console.log('='.repeat(80));
  
  // Try to fetch offer_products for Flash Sale (offer_id = 5)
  const { data, error } = await supabase
    .from('offer_products')
    .select('product_id, unit_id')
    .eq('offer_id', 5);
  
  console.log('\n📦 Data:', data);
  console.log('❌ Error:', error);
  
  if (error) {
    console.log('\n⚠️  RLS POLICY ISSUE DETECTED!');
    console.log('The frontend cannot read offer_products because RLS policy blocks it.');
    console.log('\nThis means the Edit functionality will always show (0) products.');
  } else if (data && data.length > 0) {
    console.log('\n✅ RLS is working correctly, products are accessible');
  } else {
    console.log('\n⚠️  No data returned (but no error either)');
  }
  
  console.log('\n' + '='.repeat(80));
})();
