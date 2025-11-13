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

async function checkTable() {
  try {
    // Get one record to see all columns
    const { data, error } = await supabase
      .from('offers')
      .select('*')
      .limit(1);

    if (error) {
      console.error('❌ Error:', error.message);
      return;
    }

    if (data && data.length > 0) {
      console.log('✅ Offers table columns:');
      const columns = Object.keys(data[0]);
      columns.forEach(col => {
        console.log(`   - ${col}: ${typeof data[0][col]}`);
      });
      
      console.log('\n📋 Sample data:');
      console.log(JSON.stringify(data[0], null, 2));
    } else {
      console.log('ℹ️ No offers found in table');
    }

  } catch (err) {
    console.error('💥 Error:', err);
  }
}

checkTable();
