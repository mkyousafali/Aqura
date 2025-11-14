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

async function checkOffersTable() {
  console.log('Checking offers table structure...\n');
  
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
    Object.keys(data[0]).forEach(col => {
      console.log(`   - ${col}`);
    });
  } else {
    console.log('⚠️ No data in offers table, fetching schema...');
    // Try to insert empty object to see column requirements
    const { error: insertError } = await supabase
      .from('offers')
      .insert({})
      .select();
    
    if (insertError) {
      console.log('Schema info from error:', insertError.message);
    }
  }
}

checkOffersTable().then(() => process.exit(0));
