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

async function testOfferProducts() {
  try {
    console.log('🎁 Testing offer products API...\n');
    
    // Simulate the API call
    const response = await fetch('http://localhost:5173/api/customer/featured-offers?limit=5');
    const data = await response.json();
    
    console.log('📊 API Response:', data.success ? 'SUCCESS' : 'FAILED');
    console.log('📦 Offers count:', data.offers?.length || 0);
    
    if (data.offers && data.offers.length > 0) {
      console.log('\n📋 Offers and their products:\n');
      
      data.offers.forEach((offer, i) => {
        console.log(`${i + 1}. ${offer.name_en} (Type: ${offer.type})`);
        console.log(`   Discount: ${offer.discount_type} - ${offer.discount_value}`);
        console.log(`   Products: ${offer.products?.length || 0}`);
        
        if (offer.products && offer.products.length > 0) {
          offer.products.forEach((op, j) => {
            const product = op.products;
            if (product) {
              console.log(`      ${j + 1}. ${product.name_en} - ${product.price} SAR`);
              console.log(`         Image: ${product.image_url ? 'YES' : 'NO'}`);
            }
          });
        } else {
          console.log('      ⚠️ No products found for this offer');
        }
        console.log('');
      });
      
      // Count total products across all offers
      const totalProducts = data.offers.reduce((sum, offer) => sum + (offer.products?.length || 0), 0);
      console.log(`✅ Total products in LED carousel: ${totalProducts}`);
      
    } else {
      console.log('⚠️ No offers returned from API');
    }

  } catch (err) {
    console.error('💥 Error:', err.message);
  }
}

testOfferProducts();
