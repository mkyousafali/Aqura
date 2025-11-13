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

console.log('🔗 Supabase URL:', supabaseUrl ? 'SET' : 'NOT SET');
console.log('🔑 Anon Key:', supabaseKey ? 'SET (length: ' + supabaseKey.length + ')' : 'NOT SET');

const supabase = createClient(supabaseUrl, supabaseKey);

// Test the offers query
async function testOffersQuery() {
  try {
    console.log('\n🎁 Testing offers query...');
    
    const now = new Date().toISOString();
    console.log('📅 Current time:', now);

    const { data: offers, error } = await supabase
      .from('offers')
      .select(`
        id,
        type,
        name_ar,
        name_en,
        description_ar,
        description_en,
        discount_type,
        discount_value,
        start_date,
        end_date,
        is_active,
        show_in_carousel,
        service_type
      `)
      .eq('is_active', true)
      .eq('show_in_carousel', true)
      .lte('start_date', now)
      .gte('end_date', now)
      .order('created_at', { ascending: false })
      .limit(5);

    if (error) {
      console.error('❌ Error:', error.message);
      console.error('Full error:', error);
      return;
    }

    console.log('✅ Query successful!');
    console.log('📊 Found offers:', offers?.length || 0);
    
    if (offers && offers.length > 0) {
      console.log('\n📋 Offers:');
      offers.forEach((offer, i) => {
        console.log(`\n${i + 1}. ${offer.name_en} (${offer.offer_type})`);
        console.log(`   Active: ${offer.is_active}, Featured: ${offer.is_featured}`);
        console.log(`   Period: ${offer.start_date} to ${offer.end_date}`);
      });
    } else {
      console.log('ℹ️ No active offers found matching the criteria');
      
      // Check if there are ANY offers in the table
      const { data: allOffers, error: allError } = await supabase
        .from('offers')
        .select('id, name_en, is_active, start_date, end_date')
        .limit(10);
      
      if (!allError && allOffers) {
        console.log(`\n📊 Total offers in database: ${allOffers.length}`);
        allOffers.forEach(o => {
          console.log(`   - ${o.name_en}: active=${o.is_active}, dates: ${o.start_date} to ${o.end_date}`);
        });
      }
    }

  } catch (err) {
    console.error('💥 Unexpected error:', err);
  }
}

testOffersQuery();
