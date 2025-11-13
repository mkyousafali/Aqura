import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

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

async function inspect() {
  try {
    const { data, error } = await supabase
      .from('offers')
      .select('*')
      .eq('id', 39)
      .single();

    if (error) {
      console.error('Error:', error);
      return;
    }

    console.log('Offer 39:', JSON.stringify(data, null, 2));
  } catch (err) {
    console.error('Exception:', err);
  }
}

inspect();
