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
const supabaseKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

console.log('🔗 Supabase URL:', supabaseUrl ? 'SET' : 'NOT SET');
console.log('🔑 Service Key:', supabaseKey ? 'SET' : 'NOT SET');

const supabase = createClient(supabaseUrl, supabaseKey);

async function enableCarouselForOffers() {
  try {
    console.log('\n🎁 Updating offers to show in carousel...');
    
    // Update all active offers to show in carousel
    const { data, error } = await supabase
      .from('offers')
      .update({ show_in_carousel: true })
      .eq('is_active', true)
      .select();

    if (error) {
      console.error('❌ Error:', error.message);
      return;
    }

    console.log(`✅ Updated ${data?.length || 0} offers to show in carousel`);
    
    if (data) {
      data.forEach(offer => {
        console.log(`   ✓ ${offer.name_en} (ID: ${offer.id})`);
      });
    }

  } catch (err) {
    console.error('💥 Error:', err);
  }
}

enableCarouselForOffers();
