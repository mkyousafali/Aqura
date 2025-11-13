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

async function checkOfferTables() {
  console.log('\n=== CHECKING OFFERS TABLE ===');
  const { data: offers, error: offersError } = await supabase
    .from('offers')
    .select('*')
    .eq('show_in_carousel', true)
    .eq('is_active', true)
    .limit(5);
  
  if (offersError) {
    console.error('Error:', offersError);
  } else {
    console.log(`Found ${offers.length} active carousel offers:`);
    offers.forEach(offer => {
      console.log(`\n  ID: ${offer.id}`);
      console.log(`  Type: ${offer.type}`);
      console.log(`  Name: ${offer.name_en}`);
      console.log(`  Discount Type: ${offer.discount_type}`);
      console.log(`  Discount Value: ${offer.discount_value}`);
    });
  }

  console.log('\n=== CHECKING OFFER_PRODUCTS TABLE ===');
  for (const offer of offers || []) {
    const { data: products, error: productsError } = await supabase
      .from('offer_products')
      .select('*')
      .eq('offer_id', offer.id);
    
    if (productsError) {
      console.error(`Error for offer ${offer.id}:`, productsError);
    } else {
      console.log(`\nOffer ${offer.id} (${offer.name_en}):`);
      console.log(`  ${products.length} products found`);
      if (products.length > 0) {
        products.forEach(p => {
          console.log(`    - Product ID: ${p.product_id}, Qty: ${p.offer_qty}, Percentage: ${p.offer_percentage}%, Price: ${p.offer_price}`);
        });
      }
    }
  }

  console.log('\n=== CHECKING OFFER_BUNDLES TABLE ===');
  const { data: bundles, error: bundlesError } = await supabase
    .from('offer_bundles')
    .select('*');
  
  if (bundlesError) {
    console.error('Error:', bundlesError);
  } else {
    console.log(`Found ${bundles.length} bundles:`);
    bundles.forEach(bundle => {
      console.log(`\n  Offer ID: ${bundle.offer_id}`);
      console.log(`  Bundle Name: ${bundle.bundle_name_en}`);
      console.log(`  Bundle Price: ${bundle.bundle_price}`);
    });
  }

  console.log('\n=== CHECKING BOGO_OFFER_RULES TABLE ===');
  const { data: bogo, error: bogoError } = await supabase
    .from('bogo_offer_rules')
    .select('*');
  
  if (bogoError) {
    console.error('Error:', bogoError);
  } else {
    console.log(`Found ${bogo.length} BOGO rules:`);
    bogo.forEach(rule => {
      console.log(`\n  Offer ID: ${rule.offer_id}`);
      console.log(`  Buy Product: ${rule.buy_product_id} (Qty: ${rule.buy_quantity})`);
      console.log(`  Get Product: ${rule.get_product_id} (Qty: ${rule.get_quantity})`);
      console.log(`  Discount: ${rule.get_discount_percentage}%`);
    });
  }
}

checkOfferTables().then(() => {
  console.log('\n✅ Check complete');
  process.exit(0);
}).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
