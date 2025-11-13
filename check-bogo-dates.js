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

console.log('🔍 Checking BOGO offer dates...\n');

const now = new Date().toISOString();
console.log('📅 Current time:', now);
console.log('');

// Get BOGO offer details
const { data: offers, error } = await supabase
  .from('offers')
  .select('*')
  .eq('type', 'bogo')
  .eq('id', 37)
  .single();

if (error) {
  console.error('❌ Error:', error);
  process.exit(1);
}

console.log('🎁 BOGO Offer Details:');
console.log('  ID:', offers.id);
console.log('  Name (EN):', offers.name_en);
console.log('  Name (AR):', offers.name_ar);
console.log('  Type:', offers.type);
console.log('  Start Date:', offers.start_date);
console.log('  End Date:', offers.end_date);
console.log('  Is Active:', offers.is_active);
console.log('  Show in Carousel:', offers.show_in_carousel);
console.log('');

// Check if it's within date range
const startDate = new Date(offers.start_date);
const endDate = new Date(offers.end_date);
const nowDate = new Date(now);

console.log('📊 Date Comparison:');
console.log('  Start:', startDate.toISOString());
console.log('  Now:  ', nowDate.toISOString());
console.log('  End:  ', endDate.toISOString());
console.log('');
console.log('  Is After Start?', nowDate >= startDate);
console.log('  Is Before End?', nowDate <= endDate);
console.log('  Is In Range?', nowDate >= startDate && nowDate <= endDate);
