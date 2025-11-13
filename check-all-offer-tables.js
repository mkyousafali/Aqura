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
const supabaseKey = envVars.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkTable(tableName) {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`📋 TABLE: ${tableName}`);
  console.log('='.repeat(60));
  
  try {
    const { data, error, count } = await supabase
      .from(tableName)
      .select('*', { count: 'exact' })
      .limit(2);

    if (error) {
      console.error(`❌ Error: ${error.message}`);
      return;
    }

    console.log(`📊 Total records: ${count}`);
    
    if (data && data.length > 0) {
      console.log(`\n📝 Columns:`);
      const columns = Object.keys(data[0]);
      columns.forEach(col => {
        const value = data[0][col];
        const type = value === null ? 'null' : typeof value;
        console.log(`   - ${col}: ${type}`);
      });
      
      console.log(`\n📄 Sample Record:`);
      console.log(JSON.stringify(data[0], null, 2));
      
      if (data.length > 1) {
        console.log(`\n📄 Another Sample:`);
        console.log(JSON.stringify(data[1], null, 2));
      }
    } else {
      console.log('ℹ️  No records found in table');
    }

  } catch (err) {
    console.error(`💥 Error: ${err.message}`);
  }
}

async function checkAllOfferTables() {
  console.log('🎁 Checking all offer-related tables...');
  
  const tables = [
    'offers',
    'offer_products',
    'offer_bundles',
    'bogo_offer_rules',
    'products'
  ];
  
  for (const table of tables) {
    await checkTable(table);
  }
  
  console.log(`\n${'='.repeat(60)}`);
  console.log('✅ Table inspection complete!');
  console.log('='.repeat(60));
}

checkAllOfferTables();
