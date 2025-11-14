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
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;
const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function testOfferFlow() {
  console.log('\n🔍 Testing Complete Offer Flow\n');
  console.log('='.repeat(70));

  // Get the offer
  console.log('\n📊 Step 1: Get offer #45');
  const { data: offer } = await supabase.from('offers').select('*').eq('id', 45).single();
  console.log('Offer:', offer.name_en);
  console.log('Branch ID:', offer.branch_id, '(null = all branches)');
  console.log('Service Type:', offer.service_type);

  // Get offer products
  console.log('\n📦 Step 2: Get offer products');
  const { data: offerProducts } = await supabase
    .from('offer_products')
    .select('*, products:product_id(*)')
    .eq('offer_id', 45);
  
  console.log('Found', offerProducts.length, 'product(s)');
  offerProducts.forEach(op => {
    console.log('\n  Product:', op.products.product_name_en);
    console.log('  Product ID:', op.product_id);
    console.log('  Sale Price:', op.products.sale_price);
    console.log('  Offer Price:', op.offer_price);
    console.log('  Offer Percentage:', op.offer_percentage);
    console.log('  Offer Qty:', op.offer_qty);
  });

  // Test the filtering logic
  console.log('\n🔍 Step 3: Test filtering logic');
  const testBranchId = '67890123-4567-89ab-cdef-0123456789ab'; // any branch ID
  const testServiceType = 'delivery';
  
  // Branch filter
  const passedBranchFilter = !offer.branch_id || offer.branch_id === testBranchId;
  console.log('Branch filter passed:', passedBranchFilter, '(branch_id is null, so passes)');
  
  // Service type filter
  const passedServiceFilter = !offer.service_type || offer.service_type === 'both' || offer.service_type === testServiceType;
  console.log('Service type filter passed:', passedServiceFilter, '(service_type is "both", so passes)');
  
  // Check if offer_price exists and is valid
  console.log('\n🔍 Step 4: Check special price validity');
  offerProducts.forEach(op => {
    const hasSpecialPrice = op.offer_price && op.offer_price > 0;
    console.log(`  ${op.products.product_name_en}:`);
    console.log('    offer_price:', op.offer_price);
    console.log('    hasSpecialPrice:', hasSpecialPrice);
    
    if (hasSpecialPrice) {
      const originalPrice = parseFloat(op.products.sale_price);
      const offerPrice = parseFloat(op.offer_price);
      const savings = originalPrice - offerPrice;
      const discount = Math.round((savings / originalPrice) * 100);
      
      console.log('    Original:', originalPrice, 'SAR');
      console.log('    Offer:', offerPrice, 'SAR');
      console.log('    Savings:', savings, 'SAR');
      console.log('    Discount:', discount, '%');
    }
  });

  console.log('\n' + '='.repeat(70));
  console.log('✅ Test Complete\n');
}

testOfferFlow();
