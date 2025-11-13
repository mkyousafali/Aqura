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

async function checkOfferProducts() {
  try {
    console.log('🎁 Checking offer products in database...\n');
    
    const now = new Date().toISOString();
    
    // Get active offers
    const { data: offers, error: offersError } = await supabase
      .from('offers')
      .select('id, type, name_en, discount_type, discount_value, show_in_carousel')
      .eq('is_active', true)
      .eq('show_in_carousel', true)
      .lte('start_date', now)
      .gte('end_date', now)
      .limit(5);

    if (offersError) {
      console.error('❌ Error fetching offers:', offersError.message);
      return;
    }

    console.log(`📊 Found ${offers?.length || 0} active carousel offers\n`);

    if (offers && offers.length > 0) {
      for (const offer of offers) {
        console.log(`📦 ${offer.name_en} (ID: ${offer.id})`);
        console.log(`   Type: ${offer.type}, Discount: ${offer.discount_type} ${offer.discount_value}`);
        
        // Get products for this offer
        const { data: offerProducts, error: productsError } = await supabase
          .from('offer_products')
          .select(`
            id,
            product_id,
            offer_qty,
            offer_percentage,
            offer_price,
            products:product_id (
              id,
              product_name_ar,
              product_name_en,
              sale_price,
              image_url
            )
          `)
          .eq('offer_id', offer.id);

        if (productsError) {
          console.error(`   ❌ Error fetching products: ${productsError.message}`);
          continue;
        }

        console.log(`   Products: ${offerProducts?.length || 0}`);
        
        if (offerProducts && offerProducts.length > 0) {
          offerProducts.forEach((op, i) => {
            const p = op.products;
            if (p) {
              const finalPrice = op.offer_price || (op.offer_percentage ? p.sale_price * (1 - op.offer_percentage / 100) : p.sale_price);
              console.log(`      ${i + 1}. ${p.product_name_en}`);
              console.log(`         Original: ${p.sale_price} SAR → Final: ${finalPrice.toFixed(2)} SAR`);
              console.log(`         Discount: ${op.offer_percentage ? op.offer_percentage + '%' : op.offer_price ? 'Special Price' : 'None'}`);
              console.log(`         Image: ${p.image_url ? '✓' : '✗'}`);
            }
          });
        } else {
          console.log(`      ⚠️ No products linked to this offer in offer_products table`);
        }
        console.log('');
      }
      
      // Summary
      let totalProducts = 0;
      for (const offer of offers) {
        const { count } = await supabase
          .from('offer_products')
          .select('*', { count: 'exact', head: true })
          .eq('offer_id', offer.id);
        totalProducts += count || 0;
      }
      
      console.log(`\n✅ Total products across all carousel offers: ${totalProducts}`);
      console.log(`📺 These ${totalProducts} products will appear in the LED carousel\n`);
    }

  } catch (err) {
    console.error('💥 Error:', err);
  }
}

checkOfferProducts();
