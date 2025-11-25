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

const supabaseUrl = envVars.PUBLIC_SUPABASE_URL;
const supabaseServiceKey = envVars.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkFlyerProductsStructure() {
  console.log('🔍 Checking flyer_products table structure...\n');

  // Get sample data to see current columns
  const { data, error, count } = await supabase
    .from('flyer_products')
    .select('*', { count: 'exact' })
    .limit(2);

  if (error) {
    console.error('❌ Error:', error.message);
    return;
  }

  console.log(`📊 Table: flyer_products`);
  console.log(`   Total records: ${count}`);
  
  if (data && data.length > 0) {
    console.log(`\n✅ Current Columns:`, Object.keys(data[0]));
    console.log(`\n📝 Sample Record:`, JSON.stringify(data[0], null, 2));
  }
}

checkFlyerProductsStructure();
