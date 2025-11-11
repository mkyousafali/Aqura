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
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

(async () => {
  console.log('\n🔍 Checking Offers and their Products\n');
  console.log('='.repeat(80));
  
  // Get all offers
  const { data: offers, error: offersError } = await supabase
    .from('offers')
    .select('id, name_en, type')
    .order('id');
  
  if (offersError) {
    console.error('Error fetching offers:', offersError);
    return;
  }
  
  console.log(`\n📊 Total Offers: ${offers.length}\n`);
  
  // For each offer, check products
  for (const offer of offers) {
    const { data: products, error: productsError } = await supabase
      .from('offer_products')
      .select('product_id')
      .eq('offer_id', offer.id);
    
    const productCount = products ? products.length : 0;
    
    console.log(`Offer #${offer.id}: ${offer.name_en}`);
    console.log(`  Type: ${offer.type}`);
    console.log(`  Products: ${productCount}`);
    if (productCount > 0) {
      products.forEach(p => console.log(`    - ${p.product_id}`));
    }
    console.log('');
  }
  
  console.log('='.repeat(80));
})();
