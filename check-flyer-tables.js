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

const supabaseUrl = envVars.PUBLIC_SUPABASE_URL?.replace(/["']/g, '');
const supabaseServiceKey = envVars.SUPABASE_SERVICE_ROLE_KEY?.replace(/["']/g, '');

console.log('Supabase URL:', supabaseUrl);
console.log('Service Key exists:', !!supabaseServiceKey);

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkTable(tableName) {
  console.log(`\n📊 Checking table: ${tableName}`);
  console.log('='.repeat(80));
  
  const { data, error, count } = await supabase
    .from(tableName)
    .select('*', { count: 'exact' })
    .limit(2);

  if (error) {
    console.error(`❌ Error: ${error.message}`);
    return;
  }

  console.log(`Total records: ${count}`);
  
  if (data && data.length > 0) {
    console.log(`\nColumns in ${tableName}:`);
    console.log(Object.keys(data[0]).join(', '));
    console.log(`\nSample record 1:`);
    console.log(JSON.stringify(data[0], null, 2));
    
    if (data[1]) {
      console.log(`\nSample record 2:`);
      console.log(JSON.stringify(data[1], null, 2));
    }
  } else {
    console.log('No records found');
  }
}

async function main() {
  await checkTable('flyer_products');
  await checkTable('flyer_offers');
  await checkTable('flyer_offer_products');
}

main().catch(console.error);
