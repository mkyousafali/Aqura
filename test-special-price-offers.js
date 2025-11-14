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

async function testSpecialPriceOffers() {
  console.log('\n🔍 Testing Special Price Offers Implementation\n');
  console.log('='.repeat(60));

  // Step 1: Check active product offers
  console.log('\n📊 Step 1: Checking active product offers...');
  const now = new Date().toISOString();
  const { data: offers, error: offersError } = await supabase
    .from('offers')
    .select('*')
    .eq('is_active', true)
    .eq('type', 'product')
    .lte('start_date', now)
    .gte('end_date', now);

  if (offersError) {
    console.error('❌ Error fetching offers:', offersError);
    return;
  }

  console.log(`✅ Found ${offers?.length || 0} active product offers`);
  
  if (offers && offers.length > 0) {
    offers.forEach(offer => {
      console.log(`   - ${offer.name_en} (ID: ${offer.id})`);
    });
  }

  // Step 2: Check offer products with special prices
  console.log('\n📦 Step 2: Checking offer products with special prices...');
  if (!offers || offers.length === 0) {
    console.log('⚠️  No active offers found. Cannot check offer products.');
    return;
  }

  const offerIds = offers.map(o => o.id);
  const { data: offerProducts, error: offerProductsError } = await supabase
    .from('offer_products')
    .select(`
      id,
      offer_id,
      product_id,
      offer_qty,
      offer_percentage,
      offer_price,
      max_uses,
      products:product_id (
        id,
        product_serial,
        product_name_en,
        product_name_ar,
        sale_price,
        is_active
      )
    `)
    .in('offer_id', offerIds);

  if (offerProductsError) {
    console.error('❌ Error fetching offer products:', offerProductsError);
    return;
  }

  console.log(`✅ Found ${offerProducts?.length || 0} offer products`);

  // Filter special price offers
  const specialPriceProducts = (offerProducts || []).filter(op => {
    return op.offer_price && op.offer_price > 0;
  });

  console.log(`✅ Found ${specialPriceProducts.length} products with special prices`);

  if (specialPriceProducts.length > 0) {
    console.log('\n📋 Special Price Products:');
    console.log('-'.repeat(60));
    specialPriceProducts.slice(0, 5).forEach(op => {
      const product = op.products;
      if (product) {
        const originalPrice = parseFloat(product.sale_price);
        const offerPrice = parseFloat(op.offer_price);
        const savings = originalPrice - offerPrice;
        const discountPercentage = Math.round((savings / originalPrice) * 100);

        console.log(`\n   Product: ${product.product_name_en}`);
        console.log(`   Original Price: ${originalPrice.toFixed(2)} SAR`);
        console.log(`   Offer Price: ${offerPrice.toFixed(2)} SAR`);
        console.log(`   Savings: ${savings.toFixed(2)} SAR (${discountPercentage}% OFF)`);
        console.log(`   Active: ${product.is_active ? 'Yes' : 'No'}`);
      }
    });

    if (specialPriceProducts.length > 5) {
      console.log(`\n   ... and ${specialPriceProducts.length - 5} more products`);
    }
  } else {
    console.log('\n⚠️  No special price products found!');
    console.log('\n💡 Tip: Create a special price offer in the admin panel:');
    console.log('   1. Go to Offers Management');
    console.log('   2. Create a new "Product Offer"');
    console.log('   3. Add products with "Special Price" set');
  }

  // Step 3: Test API endpoint simulation
  console.log('\n\n🌐 Step 3: Simulating API response structure...');
  console.log('-'.repeat(60));

  if (specialPriceProducts.length > 0) {
    const sampleProduct = specialPriceProducts[0];
    const product = sampleProduct.products;
    const offer = offers.find(o => o.id === sampleProduct.offer_id);

    if (product && offer) {
      const originalPrice = parseFloat(product.sale_price);
      const offerPrice = parseFloat(sampleProduct.offer_price);
      const savings = originalPrice - offerPrice;
      const discountPercentage = Math.round((savings / originalPrice) * 100);

      const apiResponse = {
        id: product.id,
        product_serial: product.product_serial,
        nameEn: product.product_name_en,
        nameAr: product.product_name_ar,
        originalPrice: originalPrice,
        offerPrice: offerPrice,
        savings: savings,
        discountPercentage: discountPercentage,
        hasOffer: true,
        offerType: 'special_price',
        offerId: offer.id,
        offerNameEn: offer.name_en,
        offerNameAr: offer.name_ar,
        offerQty: sampleProduct.offer_qty || 1,
        maxUses: sampleProduct.max_uses
      };

      console.log('\n✅ Sample API Response:');
      console.log(JSON.stringify(apiResponse, null, 2));
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log('✅ Test Complete!\n');
}

testSpecialPriceOffers();
